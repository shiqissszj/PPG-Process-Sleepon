CC ?= clang
CFLAGS ?= -O2 -std=c99 -Wall -Wextra -pedantic
LDFLAGS ?= -lm

TARGET := spo2_pr_waveform_test
TEST_SRCS := spo2_pr_waveform_test.c
GENERATED_SRCS := $(filter-out $(TEST_SRCS),$(wildcard *.c))

all: $(TARGET)

$(TARGET): $(GENERATED_SRCS) $(TEST_SRCS)
	$(CC) $(CFLAGS) -I. $(GENERATED_SRCS) $(TEST_SRCS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
