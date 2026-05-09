#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <dlfcn.h>
#include <errno.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CSV_COLUMN_COUNT 16
#define LINE_BUFFER_SIZE 16384
#define PATH_BUFFER_SIZE 4096
#define MAX_DATA_IDS 256
#define LABEL_BUFFER_SIZE 128
#define OUTPUT_PI_CAPACITY 16
#define SAMPLING_RATE 50.0

#ifdef __APPLE__
#define DEFAULT_LIB_A "build/runtime_compare/libppg_process0507.dylib"
#define DEFAULT_LIB_B "build/runtime_compare/libppg_process_0509.dylib"
#else
#define DEFAULT_LIB_A "build/runtime_compare/libppg_process0507.so"
#define DEFAULT_LIB_B "build/runtime_compare/libppg_process_0509.so"
#endif

typedef void (*ppg_process_fn)(float inputSampleR, float inputSampleIR,
                               float inputSampleG, unsigned int inputCounter,
                               float bodyMove, bool *outputFlag,
                               float *outputPR, float *outputSpO2,
                               float outputPI_data[], int outputPI_size[2],
                               float *confidenceR, float *R);
typedef void (*ppg_void_fn)(void);

typedef struct {
  float *ppg_r;
  float *ppg_ir;
  float *ppg_g;
  float *body_move;
  size_t count;
  size_t capacity;
} SampleSeries;

typedef struct {
  int data_id;
  int time_offset;
  int drop_start;
  int drop_end;
  char source_path[PATH_BUFFER_SIZE];
  SampleSeries samples;
} BenchmarkRecord;

typedef struct {
  int data_ids[MAX_DATA_IDS];
  int data_id_count;
  int repeat_count;
  char get_filename_path[PATH_BUFFER_SIZE];
  char lib_a_path[PATH_BUFFER_SIZE];
  char lib_b_path[PATH_BUFFER_SIZE];
  char label_a[LABEL_BUFFER_SIZE];
  char label_b[LABEL_BUFFER_SIZE];
} BenchmarkConfig;

typedef struct {
  const char *label;
  const char *library_path;
  void *handle;
  ppg_process_fn ppg_process;
  ppg_void_fn initialize;
  ppg_void_fn terminate;
} PpgImplementation;

typedef struct {
  double mean_total_sec;
  double std_total_sec;
  double us_per_sample;
  double ms_per_output;
  double realtime_ratio;
  double speedup_vs_realtime;
  size_t total_samples;
  size_t total_outputs;
} SuiteResult;

static void init_config(BenchmarkConfig *config);
static int parse_args(int argc, char **argv, BenchmarkConfig *config);
static int parse_data_ids(const char *text, int *ids, int *count);
static void print_usage(const char *program_name);

static int resolve_existing_file(const char *path, char *resolved,
                                 size_t resolved_size);
static int resolve_get_filename_path(const char *requested, char *resolved,
                                     size_t resolved_size);
static int get_path_dirname(const char *path, char *dir, size_t dir_size);
static int join_path(const char *dir, const char *path, char *joined,
                     size_t joined_size);
static bool file_exists(const char *path);

static int load_record_from_get_filename(const char *get_filename_path,
                                         int data_id,
                                         BenchmarkRecord *record);
static int parse_get_filename_for_id(const char *get_filename_path, int data_id,
                                     char *filename, size_t filename_size,
                                     int *time_offset, int *drop_start,
                                     int *drop_end);
static char *trim_left(char *text);
static bool line_starts_with(const char *line, const char *prefix);
static bool parse_case_id(const char *line, int *case_id);
static bool parse_int_assignment(const char *line, const char *name,
                                 int *value);
static bool parse_filename_assignment(const char *line, char *filename,
                                      size_t filename_size);

static int load_samples(const char *path, int time_offset, int drop_start,
                        int drop_end, SampleSeries *series);
static int split_csv_line(char *line, char **fields, int max_fields);
static float parse_float_field(const char *text);
static int append_sample(SampleSeries *series, float ppg_r, float ppg_ir,
                         float ppg_g, float body_move);
static int ensure_sample_capacity(SampleSeries *series, size_t required);
static int grow_capacity(size_t current_capacity, size_t required,
                         size_t *new_capacity);
static int resize_float_array(float **buffer, size_t new_capacity);
static void free_sample_series(SampleSeries *series);
static void free_records(BenchmarkRecord *records, int record_count);

static int load_implementation(PpgImplementation *impl);
static void close_implementation(PpgImplementation *impl);
static int run_suite(PpgImplementation *impl, const BenchmarkRecord *records,
                     int record_count, int repeat_count, SuiteResult *result);
static size_t run_stream_body(PpgImplementation *impl,
                              const SampleSeries *samples);
static int run_stream_once(PpgImplementation *impl, const SampleSeries *samples,
                           double *elapsed_sec, size_t *output_count);
static double monotonic_seconds(void);
static double compute_mean(const double *values, int count);
static double compute_std(const double *values, int count, double mean_value);
static void print_suite_result(const SuiteResult *result, const char *label);

int main(int argc, char **argv)
{
  BenchmarkConfig config;
  BenchmarkRecord *records = NULL;
  PpgImplementation impl_a = {0};
  PpgImplementation impl_b = {0};
  SuiteResult result_a;
  SuiteResult result_b;
  int data_index;
  int status = 1;
  char resolved_get_filename[PATH_BUFFER_SIZE];

  init_config(&config);
  if (parse_args(argc, argv, &config) != 0) {
    return 1;
  }

  if (resolve_get_filename_path(config.get_filename_path,
                                resolved_get_filename,
                                sizeof(resolved_get_filename)) != 0) {
    fprintf(stderr, "Failed to locate get_filename.m: %s\n",
            config.get_filename_path);
    return 1;
  }

  records =
      (BenchmarkRecord *)calloc((size_t)config.data_id_count, sizeof(*records));
  if (records == NULL) {
    fprintf(stderr, "Failed to allocate benchmark records.\n");
    return 1;
  }

  for (data_index = 0; data_index < config.data_id_count; ++data_index) {
    if (load_record_from_get_filename(resolved_get_filename,
                                      config.data_ids[data_index],
                                      &records[data_index]) != 0) {
      goto cleanup;
    }
  }

  impl_a.label = config.label_a;
  impl_a.library_path = config.lib_a_path;
  impl_b.label = config.label_b;
  impl_b.library_path = config.lib_b_path;

  if ((load_implementation(&impl_a) != 0) ||
      (load_implementation(&impl_b) != 0)) {
    goto cleanup;
  }

  printf("Benchmark records:");
  for (data_index = 0; data_index < config.data_id_count; ++data_index) {
    printf(" %d", records[data_index].data_id);
  }
  printf("\nRepeat count per implementation: %d\n", config.repeat_count);
  printf("get_filename.m: %s\n", resolved_get_filename);
  printf("Timing excludes CSV loading, dynamic library loading, initialize, and "
         "terminate.\n\n");

  if (run_suite(&impl_a, records, config.data_id_count, config.repeat_count,
                &result_a) != 0) {
    goto cleanup;
  }
  if (run_suite(&impl_b, records, config.data_id_count, config.repeat_count,
                &result_b) != 0) {
    goto cleanup;
  }

  printf("Summary\n");
  print_suite_result(&result_a, config.label_a);
  print_suite_result(&result_b, config.label_b);
  if (result_b.mean_total_sec > 0.0) {
    printf("%s speed vs %s: %.3f x\n", config.label_b, config.label_a,
           result_a.mean_total_sec / result_b.mean_total_sec);
  }

  status = 0;

cleanup:
  close_implementation(&impl_a);
  close_implementation(&impl_b);
  free_records(records, config.data_id_count);
  free(records);
  return status;
}

static void init_config(BenchmarkConfig *config)
{
  memset(config, 0, sizeof(*config));
  config->data_ids[0] = 222;
  config->data_ids[1] = 225;
  config->data_id_count = 2;
  config->repeat_count = 5;
  snprintf(config->get_filename_path, sizeof(config->get_filename_path),
           "../get_filename.m");
  snprintf(config->lib_a_path, sizeof(config->lib_a_path), "%s",
           DEFAULT_LIB_A);
  snprintf(config->lib_b_path, sizeof(config->lib_b_path), "%s",
           DEFAULT_LIB_B);
  snprintf(config->label_a, sizeof(config->label_a), "ppg_process0507");
  snprintf(config->label_b, sizeof(config->label_b), "ppg_process_0509");
}

static int parse_args(int argc, char **argv, BenchmarkConfig *config)
{
  int arg_index;

  for (arg_index = 1; arg_index < argc; ++arg_index) {
    const char *arg = argv[arg_index];

    if (((strcmp(arg, "--data-ids") == 0) || (strcmp(arg, "--data-id") == 0)) &&
        (arg_index + 1 < argc)) {
      if (parse_data_ids(argv[++arg_index], config->data_ids,
                         &config->data_id_count) != 0) {
        fprintf(stderr, "Invalid data id list.\n");
        return -1;
      }
    } else if ((strcmp(arg, "--repeat") == 0) && (arg_index + 1 < argc)) {
      config->repeat_count = atoi(argv[++arg_index]);
      if (config->repeat_count <= 0) {
        fprintf(stderr, "--repeat must be positive.\n");
        return -1;
      }
    } else if ((strcmp(arg, "--get-filename") == 0) &&
               (arg_index + 1 < argc)) {
      snprintf(config->get_filename_path, sizeof(config->get_filename_path),
               "%s", argv[++arg_index]);
    } else if ((strcmp(arg, "--lib-a") == 0) && (arg_index + 1 < argc)) {
      snprintf(config->lib_a_path, sizeof(config->lib_a_path), "%s",
               argv[++arg_index]);
    } else if ((strcmp(arg, "--lib-b") == 0) && (arg_index + 1 < argc)) {
      snprintf(config->lib_b_path, sizeof(config->lib_b_path), "%s",
               argv[++arg_index]);
    } else if ((strcmp(arg, "--label-a") == 0) && (arg_index + 1 < argc)) {
      snprintf(config->label_a, sizeof(config->label_a), "%s",
               argv[++arg_index]);
    } else if ((strcmp(arg, "--label-b") == 0) && (arg_index + 1 < argc)) {
      snprintf(config->label_b, sizeof(config->label_b), "%s",
               argv[++arg_index]);
    } else if ((strcmp(arg, "--help") == 0) || (strcmp(arg, "-h") == 0)) {
      print_usage(argv[0]);
      exit(0);
    } else {
      fprintf(stderr, "Unknown or incomplete argument: %s\n", arg);
      print_usage(argv[0]);
      return -1;
    }
  }

  return 0;
}

static int parse_data_ids(const char *text, int *ids, int *count)
{
  const char *cursor = text;
  int parsed_count = 0;

  while (*cursor != '\0') {
    char *end_ptr;
    long value;

    while ((*cursor != '\0') &&
           (isspace((unsigned char)*cursor) || (*cursor == ','))) {
      cursor++;
    }
    if (*cursor == '\0') {
      break;
    }

    errno = 0;
    value = strtol(cursor, &end_ptr, 10);
    if ((cursor == end_ptr) || (errno != 0) || (parsed_count >= MAX_DATA_IDS)) {
      return -1;
    }

    ids[parsed_count++] = (int)value;
    cursor = end_ptr;
  }

  if (parsed_count == 0) {
    return -1;
  }

  *count = parsed_count;
  return 0;
}

static void print_usage(const char *program_name)
{
  printf("Usage: %s [options]\n", program_name);
  printf("Options:\n");
  printf("  --data-ids 222,225       Data IDs from get_filename.m (default: 222,225)\n");
  printf("  --repeat 5               Repeat count per implementation\n");
  printf("  --get-filename PATH      Path to get_filename.m\n");
  printf("  --lib-a PATH             First dynamic library\n");
  printf("  --lib-b PATH             Second dynamic library\n");
  printf("  --label-a TEXT           Label for first implementation\n");
  printf("  --label-b TEXT           Label for second implementation\n");
}

static int resolve_existing_file(const char *path, char *resolved,
                                 size_t resolved_size)
{
  const char *prefixes[] = {"", "../", "../../", "../../../",
                            "../../../../", "../../../../../"};
  size_t prefix_index;

  if (path == NULL || path[0] == '\0') {
    return -1;
  }

  if ((path[0] == '/') && file_exists(path)) {
    snprintf(resolved, resolved_size, "%s", path);
    return 0;
  }

  for (prefix_index = 0U; prefix_index < sizeof(prefixes) / sizeof(prefixes[0]);
       ++prefix_index) {
    int written = snprintf(resolved, resolved_size, "%s%s",
                           prefixes[prefix_index], path);
    if ((written <= 0) || ((size_t)written >= resolved_size)) {
      continue;
    }
    if (file_exists(resolved)) {
      return 0;
    }
  }

  return -1;
}

static int resolve_get_filename_path(const char *requested, char *resolved,
                                     size_t resolved_size)
{
  if (resolve_existing_file(requested, resolved, resolved_size) == 0) {
    return 0;
  }
  if (resolve_existing_file("get_filename.m", resolved, resolved_size) == 0) {
    return 0;
  }
  if (resolve_existing_file("../get_filename.m", resolved, resolved_size) == 0) {
    return 0;
  }

  return -1;
}

static int get_path_dirname(const char *path, char *dir, size_t dir_size)
{
  const char *last_slash = strrchr(path, '/');
  size_t length;

  if (last_slash == NULL) {
    snprintf(dir, dir_size, ".");
    return 0;
  }

  length = (size_t)(last_slash - path);
  if (length == 0U) {
    length = 1U;
  }
  if (length >= dir_size) {
    return -1;
  }

  memcpy(dir, path, length);
  dir[length] = '\0';
  return 0;
}

static int join_path(const char *dir, const char *path, char *joined,
                     size_t joined_size)
{
  int written;

  if (path[0] == '/') {
    written = snprintf(joined, joined_size, "%s", path);
  } else if ((strcmp(dir, ".") == 0) || (dir[0] == '\0')) {
    written = snprintf(joined, joined_size, "%s", path);
  } else {
    written = snprintf(joined, joined_size, "%s/%s", dir, path);
  }

  if ((written <= 0) || ((size_t)written >= joined_size)) {
    return -1;
  }

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

static int load_record_from_get_filename(const char *get_filename_path,
                                         int data_id,
                                         BenchmarkRecord *record)
{
  char filename[PATH_BUFFER_SIZE];
  char get_filename_dir[PATH_BUFFER_SIZE];

  memset(record, 0, sizeof(*record));
  record->data_id = data_id;

  if (parse_get_filename_for_id(get_filename_path, data_id, filename,
                                sizeof(filename), &record->time_offset,
                                &record->drop_start, &record->drop_end) != 0) {
    fprintf(stderr, "Failed to resolve data ID %d from get_filename.m\n",
            data_id);
    return -1;
  }

  if (get_path_dirname(get_filename_path, get_filename_dir,
                       sizeof(get_filename_dir)) != 0) {
    fprintf(stderr, "Failed to resolve get_filename.m directory.\n");
    return -1;
  }
  if (join_path(get_filename_dir, filename, record->source_path,
                sizeof(record->source_path)) != 0) {
    fprintf(stderr, "Data path is too long for data ID %d.\n", data_id);
    return -1;
  }
  if (!file_exists(record->source_path)) {
    fprintf(stderr, "Data file for ID %d does not exist: %s\n", data_id,
            record->source_path);
    return -1;
  }

  if (load_samples(record->source_path, record->time_offset,
                   record->drop_start, record->drop_end,
                   &record->samples) != 0) {
    fprintf(stderr, "Failed to load data ID %d: %s\n", data_id,
            record->source_path);
    return -1;
  }

  printf("Loaded data ID %d: %zu samples, time_offset=%d, drop_start=%d, "
         "drop_end=%d\n",
         data_id, record->samples.count, record->time_offset,
         record->drop_start, record->drop_end);
  return 0;
}

static int parse_get_filename_for_id(const char *get_filename_path, int data_id,
                                     char *filename, size_t filename_size,
                                     int *time_offset, int *drop_start,
                                     int *drop_end)
{
  FILE *file = fopen(get_filename_path, "r");
  char line_buffer[LINE_BUFFER_SIZE];
  bool current_case_matches = false;
  bool current_is_default = false;
  bool found_explicit_rule = false;
  bool found_filename = false;

  *time_offset = -1500;
  *drop_start = 0;
  *drop_end = 1500;
  filename[0] = '\0';

  if (file == NULL) {
    return -1;
  }

  while (fgets(line_buffer, sizeof(line_buffer), file) != NULL) {
    char *line = trim_left(line_buffer);
    int case_id;

    if ((line[0] == '\0') || (line[0] == '%')) {
      continue;
    }

    if (parse_case_id(line, &case_id)) {
      current_case_matches = (case_id == data_id);
      current_is_default = false;
      continue;
    }

    if (line_starts_with(line, "otherwise")) {
      current_case_matches = false;
      current_is_default = true;
      continue;
    }

    if (current_case_matches || current_is_default) {
      int value;

      if (parse_int_assignment(line, "time_offset", &value)) {
        if (current_case_matches) {
          *time_offset = value;
          found_explicit_rule = true;
        } else if (!found_explicit_rule) {
          *time_offset = value;
        }
      } else if (parse_int_assignment(line, "drop_num_start", &value)) {
        if (current_case_matches) {
          *drop_start = value;
          found_explicit_rule = true;
        } else if (!found_explicit_rule) {
          *drop_start = value;
        }
      } else if (parse_int_assignment(line, "drop_num_end", &value)) {
        if (current_case_matches) {
          *drop_end = value;
          found_explicit_rule = true;
        } else if (!found_explicit_rule) {
          *drop_end = value;
        }
      } else if (current_case_matches &&
                 parse_filename_assignment(line, filename, filename_size)) {
        found_filename = true;
      }
    }
  }

  fclose(file);
  return found_filename ? 0 : -1;
}

static char *trim_left(char *text)
{
  while ((*text != '\0') && isspace((unsigned char)*text)) {
    text++;
  }
  return text;
}

static bool line_starts_with(const char *line, const char *prefix)
{
  size_t prefix_length = strlen(prefix);
  return strncmp(line, prefix, prefix_length) == 0;
}

static bool parse_case_id(const char *line, int *case_id)
{
  char *end_ptr;
  long value;

  if (!line_starts_with(line, "case")) {
    return false;
  }

  line += 4;
  while ((*line != '\0') && isspace((unsigned char)*line)) {
    line++;
  }

  errno = 0;
  value = strtol(line, &end_ptr, 10);
  if ((line == end_ptr) || (errno != 0)) {
    return false;
  }

  *case_id = (int)value;
  return true;
}

static bool parse_int_assignment(const char *line, const char *name, int *value)
{
  const char *name_pos = strstr(line, name);
  const char *equals_pos;
  char *end_ptr;
  long parsed_value;

  if (name_pos == NULL) {
    return false;
  }

  equals_pos = strchr(name_pos, '=');
  if (equals_pos == NULL) {
    return false;
  }

  errno = 0;
  parsed_value = strtol(equals_pos + 1, &end_ptr, 10);
  if ((equals_pos + 1 == end_ptr) || (errno != 0)) {
    return false;
  }

  *value = (int)parsed_value;
  return true;
}

static bool parse_filename_assignment(const char *line, char *filename,
                                      size_t filename_size)
{
  const char *name_pos = strstr(line, "filename");
  const char *first_quote;
  const char *second_quote;
  size_t length;

  if (name_pos == NULL) {
    return false;
  }

  first_quote = strchr(name_pos, '\'');
  if (first_quote == NULL) {
    return false;
  }
  second_quote = strchr(first_quote + 1, '\'');
  if (second_quote == NULL) {
    return false;
  }

  length = (size_t)(second_quote - first_quote - 1);
  if (length >= filename_size) {
    return false;
  }

  memcpy(filename, first_quote + 1, length);
  filename[length] = '\0';
  return true;
}

static int load_samples(const char *path, int time_offset, int drop_start,
                        int drop_end, SampleSeries *series)
{
  FILE *file = fopen(path, "r");
  char line[LINE_BUFFER_SIZE];
  SampleSeries raw_series = {0};
  long sensor_start;
  long sensor_end;
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
                      parse_float_field(fields[9])) != 0) {
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

  sensor_start = (long)drop_start - (long)time_offset;
  sensor_end = (long)raw_series.count - (long)drop_end - (long)time_offset;

  if ((sensor_start < 0) || (sensor_end <= sensor_start) ||
      (sensor_end > (long)raw_series.count)) {
    fprintf(stderr,
            "Invalid sample range after applying data rules. count=%zu "
            "start=%ld end=%ld\n",
            raw_series.count, sensor_start, sensor_end);
    free_sample_series(&raw_series);
    return -1;
  }

  for (index = (size_t)sensor_start; index < (size_t)sensor_end; ++index) {
    if (append_sample(series, raw_series.ppg_r[index],
                      raw_series.ppg_ir[index], raw_series.ppg_g[index],
                      raw_series.body_move[index]) != 0) {
      free_sample_series(&raw_series);
      free_sample_series(series);
      return -1;
    }
  }

  free_sample_series(&raw_series);
  return 0;
}

static int split_csv_line(char *line, char **fields, int max_fields)
{
  int count = 0;
  bool in_quotes = false;
  char *read_cursor = line;
  char *write_cursor = line;
  char *field_start = line;

  while (*read_cursor != '\0') {
    char ch = *read_cursor++;

    if (ch == '"') {
      if (in_quotes && (*read_cursor == '"')) {
        *write_cursor++ = *read_cursor++;
      } else {
        in_quotes = !in_quotes;
      }
      continue;
    }

    if (!in_quotes && ((ch == ',') || (ch == '\n') || (ch == '\r'))) {
      *write_cursor++ = '\0';
      if (count < max_fields) {
        fields[count++] = field_start;
      }
      field_start = write_cursor;
      if ((ch == '\n') || (ch == '\r')) {
        break;
      }
      continue;
    }

    *write_cursor++ = ch;
  }

  *write_cursor = '\0';
  if (count < max_fields) {
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

static int append_sample(SampleSeries *series, float ppg_r, float ppg_ir,
                         float ppg_g, float body_move)
{
  if (ensure_sample_capacity(series, series->count + 1U) != 0) {
    return -1;
  }

  series->ppg_r[series->count] = ppg_r;
  series->ppg_ir[series->count] = ppg_ir;
  series->ppg_g[series->count] = ppg_g;
  series->body_move[series->count] = body_move;
  series->count += 1U;
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
      (resize_float_array(&series->body_move, new_capacity) != 0)) {
    return -1;
  }

  series->capacity = new_capacity;
  return 0;
}

static int grow_capacity(size_t current_capacity, size_t required,
                         size_t *new_capacity)
{
  size_t candidate = (current_capacity == 0U) ? 4096U : current_capacity;

  while (candidate < required) {
    if (candidate > ((size_t)-1 / 2U)) {
      return -1;
    }
    candidate *= 2U;
  }

  *new_capacity = candidate;
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

static void free_sample_series(SampleSeries *series)
{
  if (series == NULL) {
    return;
  }

  free(series->ppg_r);
  free(series->ppg_ir);
  free(series->ppg_g);
  free(series->body_move);
  memset(series, 0, sizeof(*series));
}

static void free_records(BenchmarkRecord *records, int record_count)
{
  int index;

  if (records == NULL) {
    return;
  }

  for (index = 0; index < record_count; ++index) {
    free_sample_series(&records[index].samples);
  }
}

static int load_implementation(PpgImplementation *impl)
{
  impl->handle = dlopen(impl->library_path, RTLD_NOW | RTLD_LOCAL);
  if (impl->handle == NULL) {
    fprintf(stderr, "Failed to load %s: %s\n", impl->library_path, dlerror());
    return -1;
  }

  impl->ppg_process = (ppg_process_fn)dlsym(impl->handle, "ppg_process");
  impl->initialize = (ppg_void_fn)dlsym(impl->handle, "ppg_process_initialize");
  impl->terminate = (ppg_void_fn)dlsym(impl->handle, "ppg_process_terminate");

  if ((impl->ppg_process == NULL) || (impl->initialize == NULL) ||
      (impl->terminate == NULL)) {
    fprintf(stderr, "Missing ppg_process symbols in %s\n", impl->library_path);
    return -1;
  }

  return 0;
}

static void close_implementation(PpgImplementation *impl)
{
  if ((impl != NULL) && (impl->handle != NULL)) {
    dlclose(impl->handle);
    impl->handle = NULL;
  }
}

static int run_suite(PpgImplementation *impl, const BenchmarkRecord *records,
                     int record_count, int repeat_count, SuiteResult *result)
{
  double *elapsed_per_repeat =
      (double *)calloc((size_t)repeat_count, sizeof(*elapsed_per_repeat));
  size_t total_samples = 0U;
  size_t total_outputs = 0U;
  int record_index;
  int repeat_index;

  if (elapsed_per_repeat == NULL) {
    fprintf(stderr, "Failed to allocate timing buffer.\n");
    return -1;
  }

  for (record_index = 0; record_index < record_count; ++record_index) {
    const SampleSeries *samples = &records[record_index].samples;
    size_t warmup_outputs = 0U;

    total_samples += samples->count;

    if (run_stream_once(impl, samples, NULL, &warmup_outputs) != 0) {
      free(elapsed_per_repeat);
      return -1;
    }

    for (repeat_index = 0; repeat_index < repeat_count; ++repeat_index) {
      double elapsed = 0.0;
      size_t output_count = 0U;

      if (run_stream_once(impl, samples, &elapsed, &output_count) != 0) {
        free(elapsed_per_repeat);
        return -1;
      }

      elapsed_per_repeat[repeat_index] += elapsed;
      if (repeat_index == 0) {
        total_outputs += output_count;
      }
    }
  }

  result->mean_total_sec = compute_mean(elapsed_per_repeat, repeat_count);
  result->std_total_sec =
      compute_std(elapsed_per_repeat, repeat_count, result->mean_total_sec);
  result->total_samples = total_samples;
  result->total_outputs = total_outputs;
  result->us_per_sample =
      (result->mean_total_sec / (double)total_samples) * 1.0e6;
  result->ms_per_output =
      (result->mean_total_sec / (double)((total_outputs > 0U) ? total_outputs
                                                              : 1U)) *
      1.0e3;
  result->realtime_ratio =
      result->mean_total_sec / ((double)total_samples / SAMPLING_RATE);
  result->speedup_vs_realtime =
      ((double)total_samples / SAMPLING_RATE) / result->mean_total_sec;

  free(elapsed_per_repeat);
  return 0;
}

static int run_stream_once(PpgImplementation *impl, const SampleSeries *samples,
                           double *elapsed_sec, size_t *output_count)
{
  double start_time;

  impl->initialize();
  start_time = monotonic_seconds();
  *output_count = run_stream_body(impl, samples);
  if (elapsed_sec != NULL) {
    *elapsed_sec = monotonic_seconds() - start_time;
  }
  impl->terminate();
  return 0;
}

static size_t run_stream_body(PpgImplementation *impl,
                              const SampleSeries *samples)
{
  size_t sample_index;
  size_t output_count = 0U;

  for (sample_index = 0U; sample_index < samples->count; ++sample_index) {
    bool output_flag = false;
    float output_pr = 0.0F;
    float output_spo2 = 0.0F;
    float output_pi_data[OUTPUT_PI_CAPACITY];
    int output_pi_size[2] = {0, 0};
    float confidence_r = 0.0F;
    float r_value = 0.0F;

    impl->ppg_process(samples->ppg_r[sample_index],
                      samples->ppg_ir[sample_index],
                      samples->ppg_g[sample_index],
                      (unsigned int)(sample_index + 1U),
                      samples->body_move[sample_index], &output_flag,
                      &output_pr, &output_spo2, output_pi_data,
                      output_pi_size, &confidence_r, &r_value);

    if (output_flag) {
      output_count++;
    }
  }

  return output_count;
}

static double monotonic_seconds(void)
{
  struct timespec now;

  clock_gettime(CLOCK_MONOTONIC, &now);
  return (double)now.tv_sec + (double)now.tv_nsec * 1.0e-9;
}

static double compute_mean(const double *values, int count)
{
  double sum = 0.0;
  int index;

  for (index = 0; index < count; ++index) {
    sum += values[index];
  }

  return sum / (double)count;
}

static double compute_std(const double *values, int count, double mean_value)
{
  double sum_squared = 0.0;
  int index;

  if (count <= 1) {
    return 0.0;
  }

  for (index = 0; index < count; ++index) {
    double delta = values[index] - mean_value;
    sum_squared += delta * delta;
  }

  return sqrt(sum_squared / (double)(count - 1));
}

static void print_suite_result(const SuiteResult *result, const char *label)
{
  printf("%s\n", label);
  printf("  mean total time : %.6f s\n", result->mean_total_sec);
  printf("  std total time  : %.6f s\n", result->std_total_sec);
  printf("  us per sample   : %.3f\n", result->us_per_sample);
  printf("  ms per output   : %.3f\n", result->ms_per_output);
  printf("  realtime ratio  : %.6f x\n", result->realtime_ratio);
  printf("  speed vs real   : %.2f x realtime\n\n",
         result->speedup_vs_realtime);
}
