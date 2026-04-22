#include "ppg_process.h"
#include "ppg_process_initialize.h"
#include "ppg_process_terminate.h"

#include <ctype.h>
#include <errno.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CSV_COLUMN_COUNT 16
#define LINE_BUFFER_SIZE 8192
#define MODE_BUCKET_COUNT 512
#define SQI_COMPONENT_COUNT 6

typedef struct {
  const char *input_path;
  const char *output_csv;
  int data_id;
  int drop_start_override;
  int drop_end_override;
  int time_offset_override;
  bool auto_time_offset;
} TestConfig;

typedef struct {
  float *ppg_r;
  float *ppg_ir;
  float *ppg_g;
  float *body_move;
  float *ref_pr;
  float *ref_spo2;
  size_t count;
  size_t capacity;
} SampleSeries;

typedef struct {
  float *est_spo2;
  float *est_pr;
  float *confidence_r;
  float *r_value;
  float *raw_pr;
  float *confidence_g;
  float *fixed_pr;
  float *true_spo2;
  float *true_pr;
  float *sqi[6];
  size_t count;
  size_t capacity;
} WindowSeries;

typedef struct {
  float overall_spo2_rmse;
  float reliable_spo2_rmse;
  float pr_rmse;
  float reliable_ratio;
  int base_time_offset_samples;
  int spo2_auto_offset_samples;
  int pr_auto_offset_samples;
} SummaryMetrics;

static void free_sample_series(SampleSeries *series);
static void free_window_series(WindowSeries *series);
static int ensure_sample_capacity(SampleSeries *series, size_t required);
static int ensure_window_capacity(WindowSeries *series, size_t required);
static int resize_float_array(float **buffer, size_t new_capacity);
static int append_sample(SampleSeries *series, float ppg_r, float ppg_ir,
                         float ppg_g, float body_move, float ref_pr,
                         float ref_spo2);
static int append_window(WindowSeries *series, float est_spo2, float est_pr,
                         float confidence_r, float r_value, float raw_pr,
                         float confidence_g, float fixed_pr,
                         const float *sqi_values, int sqi_count,
                         float true_spo2, float true_pr);
static int split_csv_line(char *line, char **fields, int max_fields);
static float parse_float_field(const char *text);
static int load_samples(const char *path, int time_offset, int drop_start,
                        int drop_end, SampleSeries *series);
static bool file_exists(const char *path);
static int resolve_input_path(const char *input_path, char *resolved_path,
                              size_t resolved_size);
static void get_data_rules(int data_id, int *time_offset, int *drop_start,
                           int *drop_end);
static float mode_positive_integer(const float *values, size_t start_index,
                                   size_t end_index);
static int estimate_time_offset(const float *estimated, size_t estimated_count,
                                const float *truth, size_t truth_count,
                                int max_lag_windows, int step_size);
static float compute_rmse(const float *estimated, size_t estimated_count,
                          const float *truth, size_t truth_count,
                          int offset_samples, int sampling_rate,
                          const float *confidence, float confidence_threshold,
                          bool use_confidence, bool pr_only,
                          float *ratio_out);
static int write_output_csv(const char *path, const WindowSeries *series);
static void print_usage(const char *program_name);

static void init_config(TestConfig *config)
{
  config->input_path = NULL;
  config->output_csv = "spo2_pr_waveform_test_output.csv";
  config->data_id = 2014;
  config->drop_start_override = -1;
  config->drop_end_override = -1;
  config->time_offset_override = 0x7fffffff;
  config->auto_time_offset = true;
}

static int parse_args(int argc, char **argv, TestConfig *config)
{
  int arg_index;

  for (arg_index = 1; arg_index < argc; ++arg_index) {
    const char *arg = argv[arg_index];

    if ((strcmp(arg, "--file") == 0) && (arg_index + 1 < argc)) {
      config->input_path = argv[++arg_index];
    } else if ((strcmp(arg, "--data-id") == 0) && (arg_index + 1 < argc)) {
      config->data_id = atoi(argv[++arg_index]);
    } else if ((strcmp(arg, "--drop-start") == 0) &&
               (arg_index + 1 < argc)) {
      config->drop_start_override = atoi(argv[++arg_index]);
    } else if ((strcmp(arg, "--drop-end") == 0) &&
               (arg_index + 1 < argc)) {
      config->drop_end_override = atoi(argv[++arg_index]);
    } else if ((strcmp(arg, "--time-offset") == 0) &&
               (arg_index + 1 < argc)) {
      config->time_offset_override = atoi(argv[++arg_index]);
    } else if ((strcmp(arg, "--output-csv") == 0) &&
               (arg_index + 1 < argc)) {
      config->output_csv = argv[++arg_index];
    } else if (strcmp(arg, "--no-auto-offset") == 0) {
      config->auto_time_offset = false;
    } else if ((strcmp(arg, "--help") == 0) || (strcmp(arg, "-h") == 0)) {
      print_usage(argv[0]);
      return 1;
    } else {
      fprintf(stderr, "Unknown argument: %s\n", arg);
      print_usage(argv[0]);
      return -1;
    }
  }

  if (config->input_path == NULL) {
    fprintf(stderr, "Missing required argument: --file <csv_path>\n");
    print_usage(argv[0]);
    return -1;
  }

  return 0;
}

int main(int argc, char **argv)
{
  TestConfig config;
  SampleSeries samples = {0};
  WindowSeries windows = {0};
  SummaryMetrics metrics;
  char resolved_path[4096];
  int time_offset;
  int drop_start;
  int drop_end;
  int parse_status;
  const int sampling_rate = 50;
  const int step_size = 50;
  const int window_size = 150;
  size_t sample_index;
  int output_index = 0;

  init_config(&config);
  parse_status = parse_args(argc, argv, &config);
  if (parse_status != 0) {
    return (parse_status > 0) ? 0 : 1;
  }

  get_data_rules(config.data_id, &time_offset, &drop_start, &drop_end);
  if (config.drop_start_override >= 0) {
    drop_start = config.drop_start_override;
  }
  if (config.drop_end_override >= 0) {
    drop_end = config.drop_end_override;
  }
  if (config.time_offset_override != 0x7fffffff) {
    time_offset = config.time_offset_override;
  }

  if (resolve_input_path(config.input_path, resolved_path,
                         sizeof(resolved_path)) != 0) {
    fprintf(stderr, "Failed to locate input file: %s\n", config.input_path);
    return 1;
  }

  if (load_samples(resolved_path, time_offset, drop_start, drop_end,
                   &samples) != 0) {
    free_sample_series(&samples);
    return 1;
  }

  if (samples.count < (size_t)window_size) {
    fprintf(stderr, "Not enough samples after alignment and dropping: %zu\n",
            samples.count);
    free_sample_series(&samples);
    return 1;
  }

  if (ensure_window_capacity(&windows,
                             (samples.count - (size_t)window_size) /
                                     (size_t)step_size +
                                 1U) != 0) {
    fprintf(stderr, "Failed to allocate output buffers.\n");
    free_sample_series(&samples);
    free_window_series(&windows);
    return 1;
  }

  ppg_process_initialize();

  for (sample_index = 0; sample_index < samples.count; ++sample_index) {
    bool output_flag = false;
    float output_pr = 0.0f;
    float output_spo2 = 0.0f;
    float output_pi_data[SQI_COMPONENT_COUNT];
    int output_pi_size[2] = {0, 0};
    float confidence_r = 0.0f;
    float r_value = 0.0f;
    float raw_pr = 0.0f;
    float confidence_g = 0.0f;
    float fixed_pr = 0.0f;
    size_t mode_start;
    float true_spo2;
    float true_pr;

    ppg_process(samples.ppg_r[sample_index], samples.ppg_ir[sample_index],
                samples.ppg_g[sample_index], (unsigned int)(sample_index + 1U),
                samples.body_move[sample_index], &output_flag, &output_pr,
                &output_spo2, output_pi_data, output_pi_size, &confidence_r,
                &r_value, &raw_pr, &confidence_g, &fixed_pr);

    if (!output_flag) {
      continue;
    }

    mode_start = sample_index + 1U - (size_t)step_size;
    true_spo2 =
        mode_positive_integer(samples.ref_spo2, mode_start, sample_index);
    if (isnan(true_spo2) && (output_index > 0)) {
      true_spo2 = windows.true_spo2[(size_t)output_index - 1U];
    }

    true_pr = mode_positive_integer(samples.ref_pr, mode_start, sample_index);
    if (isnan(true_pr) && (output_index > 0)) {
      true_pr = windows.true_pr[(size_t)output_index - 1U];
    }
    if (!isnan(true_pr) && (true_pr > 100.0f)) {
      true_pr = 100.0f;
    }

    if (append_window(&windows, output_spo2, output_pr, confidence_r, r_value,
                      raw_pr, confidence_g, fixed_pr, output_pi_data,
                      output_pi_size[0] * output_pi_size[1], true_spo2,
                      true_pr) != 0) {
      fprintf(stderr, "Failed to append output window.\n");
      ppg_process_terminate();
      free_sample_series(&samples);
      free_window_series(&windows);
      return 1;
    }

    output_index++;
  }

  ppg_process_terminate();

  metrics.base_time_offset_samples = time_offset;
  metrics.pr_auto_offset_samples = 0;
  metrics.spo2_auto_offset_samples = 0;
  if (config.auto_time_offset) {
    metrics.pr_auto_offset_samples =
        estimate_time_offset(windows.est_pr, windows.count, windows.true_pr,
                             windows.count, 120, step_size);
    metrics.spo2_auto_offset_samples = estimate_time_offset(
        windows.est_spo2, windows.count, windows.true_spo2, windows.count,
        120, step_size);
  }

  metrics.overall_spo2_rmse = compute_rmse(
      windows.est_spo2, windows.count, windows.true_spo2, windows.count,
      metrics.spo2_auto_offset_samples, sampling_rate, NULL, 0.0f, false,
      false, NULL);
  metrics.reliable_spo2_rmse = compute_rmse(
      windows.est_spo2, windows.count, windows.true_spo2, windows.count,
      metrics.spo2_auto_offset_samples, sampling_rate, windows.confidence_r,
      0.75f, true, false, &metrics.reliable_ratio);
  metrics.pr_rmse = compute_rmse(
      windows.est_pr, windows.count, windows.true_pr, windows.count,
      metrics.pr_auto_offset_samples, sampling_rate, NULL, 0.0f, false, true,
      NULL);

  if (write_output_csv(config.output_csv, &windows) != 0) {
    fprintf(stderr, "Failed to write output CSV: %s\n", config.output_csv);
    free_sample_series(&samples);
    free_window_series(&windows);
    return 1;
  }

  printf("Input file: %s\n", resolved_path);
  printf("Data ID: %d\n", config.data_id);
  printf("Time offset from rules (samples): %d\n",
         metrics.base_time_offset_samples);
  printf("Drop start: %d\n", drop_start);
  printf("Drop end: %d\n", drop_end);
  printf("Window number: %zu\n", windows.count);
  printf("Overall SpO2 RMSE %.4f\n", metrics.overall_spo2_rmse);
  printf("Reliable SpO2 RMSE %.4f\n", metrics.reliable_spo2_rmse);
  printf("PR RMSE %.4f\n", metrics.pr_rmse);
  printf("Reliable ratio %.4f\n", metrics.reliable_ratio);
  printf("Auto SpO2 offset (samples): %d\n",
         metrics.spo2_auto_offset_samples);
  printf("Auto PR offset (samples): %d\n", metrics.pr_auto_offset_samples);
  printf("Total SpO2 offset (samples): %d\n",
         metrics.base_time_offset_samples + metrics.spo2_auto_offset_samples);
  printf("Total PR offset (samples): %d\n",
         metrics.base_time_offset_samples + metrics.pr_auto_offset_samples);
  printf("Output CSV: %s\n", config.output_csv);

  free_sample_series(&samples);
  free_window_series(&windows);
  return 0;
}

static void free_sample_series(SampleSeries *series)
{
  free(series->ppg_r);
  free(series->ppg_ir);
  free(series->ppg_g);
  free(series->body_move);
  free(series->ref_pr);
  free(series->ref_spo2);
  memset(series, 0, sizeof(*series));
}

static void free_window_series(WindowSeries *series)
{
  int sqi_index;

  free(series->est_spo2);
  free(series->est_pr);
  free(series->confidence_r);
  free(series->r_value);
  free(series->raw_pr);
  free(series->confidence_g);
  free(series->fixed_pr);
  free(series->true_spo2);
  free(series->true_pr);
  for (sqi_index = 0; sqi_index < SQI_COMPONENT_COUNT; ++sqi_index) {
    free(series->sqi[sqi_index]);
  }
  memset(series, 0, sizeof(*series));
}

static int grow_capacity(size_t current_capacity, size_t required,
                         size_t *new_capacity)
{
  size_t candidate = (current_capacity == 0U) ? 256U : current_capacity;

  while (candidate < required) {
    if (candidate > (SIZE_MAX / 2U)) {
      return -1;
    }
    candidate *= 2U;
  }

  *new_capacity = candidate;
  return 0;
}

static int ensure_sample_capacity(SampleSeries *series, size_t required)
{
  size_t new_capacity;

  if (required <= series->capacity) {
    return 0;
  }

  if (grow_capacity(series->capacity, required, &new_capacity) != 0) {
    return -1;
  }

  if ((resize_float_array(&series->ppg_r, new_capacity) != 0) ||
      (resize_float_array(&series->ppg_ir, new_capacity) != 0) ||
      (resize_float_array(&series->ppg_g, new_capacity) != 0) ||
      (resize_float_array(&series->body_move, new_capacity) != 0) ||
      (resize_float_array(&series->ref_pr, new_capacity) != 0) ||
      (resize_float_array(&series->ref_spo2, new_capacity) != 0)) {
    return -1;
  }

  series->capacity = new_capacity;
  return 0;
}

static int ensure_window_capacity(WindowSeries *series, size_t required)
{
  size_t new_capacity;
  int sqi_index;

  if (required <= series->capacity) {
    return 0;
  }

  if (grow_capacity(series->capacity, required, &new_capacity) != 0) {
    return -1;
  }

  if ((resize_float_array(&series->est_spo2, new_capacity) != 0) ||
      (resize_float_array(&series->est_pr, new_capacity) != 0) ||
      (resize_float_array(&series->confidence_r, new_capacity) != 0) ||
      (resize_float_array(&series->r_value, new_capacity) != 0) ||
      (resize_float_array(&series->raw_pr, new_capacity) != 0) ||
      (resize_float_array(&series->confidence_g, new_capacity) != 0) ||
      (resize_float_array(&series->fixed_pr, new_capacity) != 0) ||
      (resize_float_array(&series->true_spo2, new_capacity) != 0) ||
      (resize_float_array(&series->true_pr, new_capacity) != 0)) {
    return -1;
  }

  for (sqi_index = 0; sqi_index < SQI_COMPONENT_COUNT; ++sqi_index) {
    if (resize_float_array(&series->sqi[sqi_index], new_capacity) != 0) {
      return -1;
    }
  }

  series->capacity = new_capacity;
  return 0;
}

static int resize_float_array(float **buffer, size_t new_capacity)
{
  float *new_buffer = (float *)realloc(*buffer, new_capacity * sizeof(float));

  if (new_buffer == NULL) {
    return -1;
  }

  *buffer = new_buffer;
  return 0;
}

static int append_sample(SampleSeries *series, float ppg_r, float ppg_ir,
                         float ppg_g, float body_move, float ref_pr,
                         float ref_spo2)
{
  if (ensure_sample_capacity(series, series->count + 1U) != 0) {
    return -1;
  }

  series->ppg_r[series->count] = ppg_r;
  series->ppg_ir[series->count] = ppg_ir;
  series->ppg_g[series->count] = ppg_g;
  series->body_move[series->count] = body_move;
  series->ref_pr[series->count] = ref_pr;
  series->ref_spo2[series->count] = ref_spo2;
  series->count += 1U;
  return 0;
}

static int append_window(WindowSeries *series, float est_spo2, float est_pr,
                         float confidence_r, float r_value, float raw_pr,
                         float confidence_g, float fixed_pr,
                         const float *sqi_values, int sqi_count,
                         float true_spo2, float true_pr)
{
  int sqi_index;

  if (ensure_window_capacity(series, series->count + 1U) != 0) {
    return -1;
  }

  series->est_spo2[series->count] = est_spo2;
  series->est_pr[series->count] = est_pr;
  series->confidence_r[series->count] = confidence_r;
  series->r_value[series->count] = r_value;
  series->raw_pr[series->count] = raw_pr;
  series->confidence_g[series->count] = confidence_g;
  series->fixed_pr[series->count] = fixed_pr;
  series->true_spo2[series->count] = true_spo2;
  series->true_pr[series->count] = true_pr;
  for (sqi_index = 0; sqi_index < SQI_COMPONENT_COUNT; ++sqi_index) {
    series->sqi[sqi_index][series->count] =
        (sqi_index < sqi_count) ? sqi_values[sqi_index] : NAN;
  }
  series->count += 1U;
  return 0;
}

static int split_csv_line(char *line, char **fields, int max_fields)
{
  int count = 0;
  char *cursor = line;
  char *field_start = line;

  while (*cursor != '\0') {
    if ((*cursor == ',') || (*cursor == '\n') || (*cursor == '\r')) {
      *cursor = '\0';
      if (count < max_fields) {
        fields[count++] = field_start;
      }
      field_start = cursor + 1;
      if ((cursor[1] == '\n') || (cursor[1] == '\r')) {
        cursor[1] = '\0';
      }
    }
    cursor++;
  }

  if ((count < max_fields) && (*field_start != '\0')) {
    fields[count++] = field_start;
  } else if ((count < max_fields) && (cursor == field_start)) {
    fields[count++] = field_start;
  }

  return count;
}

static float parse_float_field(const char *text)
{
  char *end_ptr;
  float value;

  while ((*text != '\0') && isspace((unsigned char)*text)) {
    text++;
  }

  if (*text == '\0') {
    return NAN;
  }

  errno = 0;
  value = strtof(text, &end_ptr);
  if ((text == end_ptr) || (errno != 0)) {
    return NAN;
  }

  return value;
}

static int load_samples(const char *path, int time_offset, int drop_start,
                        int drop_end, SampleSeries *series)
{
  FILE *file = fopen(path, "r");
  char line[LINE_BUFFER_SIZE];
  SampleSeries raw_series = {0};
  size_t sensor_start;
  size_t sensor_end;
  size_t ref_start;
  size_t ref_end;
  size_t aligned_count;
  size_t index;

  if (file == NULL) {
    fprintf(stderr, "Failed to open CSV file: %s\n", path);
    return -1;
  }

  if (fgets(line, sizeof(line), file) == NULL) {
    fclose(file);
    fprintf(stderr, "CSV file is empty: %s\n", path);
    return -1;
  }

  while (fgets(line, sizeof(line), file) != NULL) {
    char *fields[CSV_COLUMN_COUNT];
    int field_count = split_csv_line(line, fields, CSV_COLUMN_COUNT);

    if (field_count < 10) {
      continue;
    }

    if (append_sample(&raw_series, parse_float_field(fields[2]),
                      parse_float_field(fields[3]),
                      parse_float_field(fields[4]),
                      parse_float_field(fields[9]),
                      parse_float_field(fields[6]),
                      parse_float_field(fields[5])) != 0) {
      fclose(file);
      free_sample_series(&raw_series);
      return -1;
    }
  }

  fclose(file);

  if ((drop_start < 0) || (drop_end < 0)) {
    fprintf(stderr, "Drop range must be non-negative.\n");
    free_sample_series(&raw_series);
    return -1;
  }

  if ((size_t)(drop_start + drop_end) >= raw_series.count) {
    fprintf(stderr,
            "Drop range exceeds loaded samples. count=%zu drop_start=%d "
            "drop_end=%d\n",
            raw_series.count, drop_start, drop_end);
    free_sample_series(&raw_series);
    return -1;
  }

  if ((drop_start - time_offset) < 0) {
    fprintf(stderr,
            "Aligned sensor start is negative. drop_start=%d time_offset=%d\n",
            drop_start, time_offset);
    free_sample_series(&raw_series);
    return -1;
  }

  if ((int)raw_series.count - drop_end - time_offset < 0) {
    fprintf(stderr,
            "Aligned sensor end is negative. count=%zu drop_end=%d "
            "time_offset=%d\n",
            raw_series.count, drop_end, time_offset);
    free_sample_series(&raw_series);
    return -1;
  }

  sensor_start = (size_t)(drop_start - time_offset);
  sensor_end = (size_t)((int)raw_series.count - drop_end - time_offset);
  ref_start = (size_t)drop_start;
  ref_end = raw_series.count - (size_t)drop_end;

  if ((sensor_start > raw_series.count) || (sensor_end > raw_series.count) ||
      (ref_start > raw_series.count) || (ref_end > raw_series.count) ||
      (sensor_start >= sensor_end) || (ref_start >= ref_end)) {
    fprintf(stderr, "Invalid aligned ranges after applying time offset.\n");
    free_sample_series(&raw_series);
    return -1;
  }

  aligned_count = sensor_end - sensor_start;
  if ((ref_end - ref_start) < aligned_count) {
    aligned_count = ref_end - ref_start;
  }

  for (index = 0; index < aligned_count; ++index) {
    if (append_sample(series, raw_series.ppg_r[sensor_start + index],
                      raw_series.ppg_ir[sensor_start + index],
                      raw_series.ppg_g[sensor_start + index],
                      raw_series.body_move[sensor_start + index],
                      raw_series.ref_pr[ref_start + index],
                      raw_series.ref_spo2[ref_start + index]) != 0) {
      free_sample_series(&raw_series);
      free_sample_series(series);
      return -1;
    }
  }

  free_sample_series(&raw_series);
  return 0;
}

static bool file_exists(const char *path)
{
  FILE *file = fopen(path, "r");

  if (file == NULL) {
    return false;
  }

  fclose(file);
  return true;
}

static int resolve_input_path(const char *input_path, char *resolved_path,
                              size_t resolved_size)
{
  const char *prefixes[] = {"", "../", "../../", "../../../",
                            "../../../../", "../../../../../"};
  size_t prefix_index;

  for (prefix_index = 0; prefix_index < sizeof(prefixes) / sizeof(prefixes[0]);
       ++prefix_index) {
    int written = snprintf(resolved_path, resolved_size, "%s%s",
                           prefixes[prefix_index], input_path);
    if ((written <= 0) || ((size_t)written >= resolved_size)) {
      continue;
    }
    if (file_exists(resolved_path)) {
      return 0;
    }
  }

  return -1;
}

static void get_data_rules(int data_id, int *time_offset, int *drop_start,
                           int *drop_end)
{
  *time_offset = -1500;
  *drop_start = 0;
  *drop_end = 1500;

  switch (data_id) {
  case 196:
    *time_offset = -3000;
    *drop_end = 3000;
    break;
  case 197:
    *time_offset = -2000;
    *drop_end = 2000;
    break;
  case 208:
    *time_offset = -2000;
    *drop_end = 5000;
    break;
  case 215:
  case 216:
    *time_offset = -3000;
    *drop_end = 3000;
    break;
  case 221:
    *time_offset = -1200;
    *drop_end = 1200;
    break;
  case 225:
    *drop_start = 5000;
    *drop_end = 1500;
    break;
  case 227:
    *drop_start = 3000;
    *drop_end = 1500;
    break;
  case 228:
    *time_offset = -1750;
    *drop_start = 2500;
    *drop_end = 1750;
    break;
  case 229:
    *time_offset = -1750;
    *drop_start = 0;
    *drop_end = 0;
    break;
  case 1001:
    *time_offset = 0;
    *drop_start = 4000;
    *drop_end = 2000;
    break;
  case 1004:
    *time_offset = 0;
    *drop_start = 1500;
    *drop_end = 500;
    break;
  case 1013:
    *time_offset = 0;
    *drop_start = 1500;
    *drop_end = 10000;
    break;
  case 1017:
    *time_offset = 0;
    *drop_start = 0;
    *drop_end = 1500;
    break;
  case 1018:
    *time_offset = 0;
    *drop_start = 1500;
    *drop_end = 190000;
    break;
  case 1019:
    *time_offset = 0;
    *drop_start = 5500;
    *drop_end = 1500;
    break;
  case 1020:
    *time_offset = 0;
    *drop_start = 5500;
    *drop_end = 100000;
    break;
  case 2001:
    *time_offset = 0;
    *drop_start = 500;
    *drop_end = 1000;
    break;
  case 2002:
    *time_offset = 0;
    *drop_start = 1250;
    *drop_end = 1000;
    break;
  default:
    break;
  }
}

static float mode_positive_integer(const float *values, size_t start_index,
                                   size_t end_index)
{
  int counts[MODE_BUCKET_COUNT];
  int best_value = -1;
  int best_count = 0;
  size_t index;

  memset(counts, 0, sizeof(counts));

  for (index = start_index; index <= end_index; ++index) {
    float value = values[index];
    int bucket;

    if (!isfinite(value) || (value <= 0.0f)) {
      continue;
    }

    bucket = (int)lroundf(value);
    if ((bucket < 0) || (bucket >= MODE_BUCKET_COUNT)) {
      continue;
    }

    counts[bucket] += 1;
    if ((counts[bucket] > best_count) ||
        ((counts[bucket] == best_count) && ((best_value < 0) ||
                                            (bucket < best_value)))) {
      best_count = counts[bucket];
      best_value = bucket;
    }
  }

  if (best_count == 0) {
    return NAN;
  }

  return (float)best_value;
}

static int estimate_time_offset(const float *estimated, size_t estimated_count,
                                const float *truth, size_t truth_count,
                                int max_lag_windows, int step_size)
{
  size_t count = (estimated_count < truth_count) ? estimated_count : truth_count;
  int max_search;
  int lag;
  double best_corr = -INFINITY;
  int best_lag = 0;

  if (count < 5U) {
    return 0;
  }

  max_search = (int)(count / 2U);
  if (max_search > max_lag_windows) {
    max_search = max_lag_windows;
  }

  for (lag = -max_search; lag <= max_search; ++lag) {
    size_t start_est = (lag >= 0) ? (size_t)lag : 0U;
    size_t start_truth = (lag >= 0) ? 0U : (size_t)(-lag);
    size_t length = count - ((lag >= 0) ? (size_t)lag : (size_t)(-lag));
    double mean_est = 0.0;
    double mean_truth = 0.0;
    double numerator = 0.0;
    double denom_est = 0.0;
    double denom_truth = 0.0;
    size_t valid_count = 0U;
    size_t index;

    for (index = 0U; index < length; ++index) {
      float est_value = estimated[start_est + index];
      float truth_value = truth[start_truth + index];

      if (!isfinite(est_value) || !isfinite(truth_value) ||
          (est_value <= 0.0f) || (truth_value <= 0.0f)) {
        continue;
      }

      mean_est += est_value;
      mean_truth += truth_value;
      valid_count++;
    }

    if (valid_count < 5U) {
      continue;
    }

    mean_est /= (double)valid_count;
    mean_truth /= (double)valid_count;

    for (index = 0U; index < length; ++index) {
      float est_value = estimated[start_est + index];
      float truth_value = truth[start_truth + index];
      double centered_est;
      double centered_truth;

      if (!isfinite(est_value) || !isfinite(truth_value) ||
          (est_value <= 0.0f) || (truth_value <= 0.0f)) {
        continue;
      }

      centered_est = (double)est_value - mean_est;
      centered_truth = (double)truth_value - mean_truth;
      numerator += centered_est * centered_truth;
      denom_est += centered_est * centered_est;
      denom_truth += centered_truth * centered_truth;
    }

    if ((denom_est <= 0.0) || (denom_truth <= 0.0)) {
      continue;
    }

    if ((numerator / sqrt(denom_est * denom_truth)) > best_corr) {
      best_corr = numerator / sqrt(denom_est * denom_truth);
      best_lag = lag;
    }
  }

  return best_lag * step_size;
}

static float compute_rmse(const float *estimated, size_t estimated_count,
                          const float *truth, size_t truth_count,
                          int offset_samples, int sampling_rate,
                          const float *confidence, float confidence_threshold,
                          bool use_confidence, bool pr_only,
                          float *ratio_out)
{
  int offset_windows =
      (int)lround((double)offset_samples / (double)sampling_rate);
  size_t start_est = (offset_windows >= 0) ? (size_t)offset_windows : 0U;
  size_t start_truth = (offset_windows >= 0) ? 0U : (size_t)(-offset_windows);
  size_t available_est =
      (start_est < estimated_count) ? (estimated_count - start_est) : 0U;
  size_t available_truth =
      (start_truth < truth_count) ? (truth_count - start_truth) : 0U;
  size_t length =
      (available_est < available_truth) ? available_est : available_truth;
  double sum_squared_error = 0.0;
  size_t valid_count = 0U;
  size_t reliable_count = 0U;
  size_t index;

  if (ratio_out != NULL) {
    *ratio_out = 0.0f;
  }

  for (index = 0U; index < length; ++index) {
    float est_value = estimated[start_est + index];
    float truth_value = truth[start_truth + index];

    if (!isfinite(est_value) || !isfinite(truth_value)) {
      continue;
    }

    if (pr_only && ((est_value <= 0.0f) || (truth_value <= 0.0f))) {
      continue;
    }

    if (use_confidence) {
      float conf_value = confidence[start_est + index];
      if (!isfinite(conf_value)) {
        continue;
      }
      if (conf_value <= confidence_threshold) {
        continue;
      }
      reliable_count++;
    }

    sum_squared_error +=
        ((double)est_value - (double)truth_value) *
        ((double)est_value - (double)truth_value);
    valid_count++;
  }

  if ((ratio_out != NULL) && (length > 0U)) {
    *ratio_out = (float)((double)reliable_count / (double)length);
  }

  if (valid_count == 0U) {
    return NAN;
  }

  return (float)sqrt(sum_squared_error / (double)valid_count);
}

static int write_output_csv(const char *path, const WindowSeries *series)
{
  FILE *file = fopen(path, "w");
  size_t index;

  if (file == NULL) {
    return -1;
  }

  fprintf(file,
          "window_index,estimated_spo2,estimated_pr,confidence_r,r_value,"
          "raw_pr,confidence_g,fixed_pr,sqi_1,sqi_2,sqi_3,sqi_4,sqi_5,sqi_6,"
          "true_spo2,true_pr\n");

  for (index = 0U; index < series->count; ++index) {
    fprintf(file,
            "%zu,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,"
            "%.9g,%.9g,%.9g,%.9g\n",
            index + 1U, series->est_spo2[index], series->est_pr[index],
            series->confidence_r[index], series->r_value[index],
            series->raw_pr[index], series->confidence_g[index],
            series->fixed_pr[index], series->sqi[0][index],
            series->sqi[1][index], series->sqi[2][index], series->sqi[3][index],
            series->sqi[4][index], series->sqi[5][index],
            series->true_spo2[index], series->true_pr[index]);
  }

  fclose(file);
  return 0;
}

static void print_usage(const char *program_name)
{
  fprintf(stderr,
          "Usage:\n"
          "  %s --file <csv_path> [--data-id <id>] [--drop-start <n>]\n"
          "     [--drop-end <n>] [--time-offset <samples>]\n"
          "     [--output-csv <path>] [--no-auto-offset]\n\n"
          "Examples:\n"
          "  %s --file "
          "\"../../Data/PPG_Collection/Low_SpO2/.../merged.txt\" "
          "--data-id 2014\n"
          "  %s --file \"../../Data/.../merged.txt\" --data-id 1007 "
          "--time-offset 0\n",
          program_name, program_name, program_name);
}
