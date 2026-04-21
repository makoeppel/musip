#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint8_t  valid;
    uint8_t  datak;
    uint32_t data;
} beat_t;

enum {
    SWB_LANE_COUNT = 4,
};

static beat_t *lane_expected[SWB_LANE_COUNT];
static size_t  lane_count[SWB_LANE_COUNT];
static size_t  lane_index[SWB_LANE_COUNT];
static beat_t *egress_expected;
static size_t  egress_count;
static size_t  egress_index;
static size_t  egress_required_count;
static int     initialized;

static void swb_die(const char *fmt, ...)
{
    va_list ap;

    fprintf(stderr, "swb_opq_2env_dpi: ");
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
    fflush(stderr);
    exit(2);
}

static void swb_reset_state(void)
{
    int lane;

    for (lane = 0; lane < SWB_LANE_COUNT; lane++) {
        free(lane_expected[lane]);
        lane_expected[lane] = NULL;
        lane_count[lane] = 0;
        lane_index[lane] = 0;
    }

    free(egress_expected);
    egress_expected = NULL;
    egress_count = 0;
    egress_index = 0;
    egress_required_count = 0;
    initialized = 0;
}

static beat_t swb_unpack_beat(uint64_t packed_word)
{
    beat_t beat;

    beat.valid = (packed_word >> 36) & 0x1u;
    beat.datak = (packed_word >> 32) & 0xFu;
    beat.data = packed_word & 0xFFFFffffu;
    return beat;
}

static void swb_load_mem_file(const char *path, beat_t **beats_out, size_t *count_out)
{
    FILE  *handle;
    char   line_buf[256];
    beat_t *beats;
    size_t count;
    size_t cap;

    handle = fopen(path, "r");
    if (handle == NULL) {
        swb_die("unable to open replay file %s: %s", path, strerror(errno));
    }

    beats = NULL;
    count = 0;
    cap = 0;

    while (fgets(line_buf, sizeof(line_buf), handle) != NULL) {
        char *cursor;
        char *endptr;
        uint64_t packed_word;

        cursor = line_buf;
        while ((*cursor == ' ') || (*cursor == '\t') || (*cursor == '\n') || (*cursor == '\r')) {
            cursor++;
        }

        if ((*cursor == '\0') || (*cursor == '#')) {
            continue;
        }

        errno = 0;
        packed_word = strtoull(cursor, &endptr, 16);
        if ((errno != 0) || (cursor == endptr)) {
            swb_die("malformed replay word in %s: %s", path, cursor);
        }

        if (count == cap) {
            size_t next_cap;
            beat_t *next_beats;

            next_cap = (cap == 0) ? 256u : (cap * 2u);
            next_beats = (beat_t *)realloc(beats, next_cap * sizeof(*beats));
            if (next_beats == NULL) {
                swb_die("out of memory while loading %s", path);
            }
            beats = next_beats;
            cap = next_cap;
        }

        beats[count++] = swb_unpack_beat(packed_word);
    }

    fclose(handle);
    *beats_out = beats;
    *count_out = count;
}

void swb_opq_2env_init(const char *replay_dir)
{
    char path_buf[4096];
    int  lane;

    if ((replay_dir == NULL) || (replay_dir[0] == '\0')) {
        swb_die("replay_dir must not be empty");
    }

    swb_reset_state();

    for (lane = 0; lane < SWB_LANE_COUNT; lane++) {
        snprintf(path_buf, sizeof(path_buf), "%s/lane%d_ingress.mem", replay_dir, lane);
        swb_load_mem_file(path_buf, &lane_expected[lane], &lane_count[lane]);
    }

    snprintf(path_buf, sizeof(path_buf), "%s/opq_egress.mem", replay_dir);
    swb_load_mem_file(path_buf, &egress_expected, &egress_count);

    egress_required_count = egress_count;
    while ((egress_required_count != 0u) && (egress_expected[egress_required_count - 1u].valid == 0u)) {
        egress_required_count--;
    }

    initialized = 1;

    fprintf(
        stderr,
        "swb_opq_2env_dpi: init replay_dir=%s lane_beats=[%zu %zu %zu %zu] opq_egress=%zu required=%zu\n",
        replay_dir,
        lane_count[0],
        lane_count[1],
        lane_count[2],
        lane_count[3],
        egress_count,
        egress_required_count
    );
}

void swb_opq_2env_push_ingress(int lane, int valid, unsigned int data, unsigned int datak)
{
    beat_t expected;

    if (!initialized) {
        swb_die("push_ingress called before init");
    }
    if ((lane < 0) || (lane >= SWB_LANE_COUNT)) {
        swb_die("invalid lane index %d", lane);
    }
    if (lane_index[lane] >= lane_count[lane]) {
        swb_die("unexpected extra ingress beat on lane %d", lane);
    }

    expected = lane_expected[lane][lane_index[lane]];
    if ((expected.valid != (uint8_t)(valid & 0x1)) ||
        (expected.datak != (uint8_t)(datak & 0xF)) ||
        (expected.data != (uint32_t)data)) {
        swb_die(
            "lane %d beat[%zu] mismatch expected={v=%u datak=0x%X data=0x%08X} actual={v=%u datak=0x%X data=0x%08X}",
            lane,
            lane_index[lane],
            expected.valid,
            expected.datak,
            expected.data,
            valid & 0x1,
            datak & 0xF,
            data
        );
    }

    lane_index[lane]++;
}

void swb_opq_2env_step_egress(int *valid, unsigned int *data, unsigned int *datak)
{
    beat_t beat;

    if (!initialized) {
        swb_die("step_egress called before init");
    }

    if ((valid == NULL) || (data == NULL) || (datak == NULL)) {
        swb_die("step_egress called with null output pointers");
    }

    if (egress_index < egress_count) {
        beat = egress_expected[egress_index++];
    } else {
        beat.valid = 0u;
        beat.datak = 0u;
        beat.data = 0u;
    }

    *valid = beat.valid;
    *data = beat.data;
    *datak = beat.datak;
}

int swb_opq_2env_check_complete(void)
{
    int lane;
    int ok;

    if (!initialized) {
        swb_die("check_complete called before init");
    }

    ok = 1;
    for (lane = 0; lane < SWB_LANE_COUNT; lane++) {
        if (lane_index[lane] != lane_count[lane]) {
            fprintf(
                stderr,
                "swb_opq_2env_dpi: lane %d incomplete consumed=%zu expected=%zu\n",
                lane,
                lane_index[lane],
                lane_count[lane]
            );
            ok = 0;
        }
    }

    if (egress_index < egress_required_count) {
        fprintf(
            stderr,
            "swb_opq_2env_dpi: opq egress incomplete consumed=%zu required=%zu total=%zu\n",
            egress_index,
            egress_required_count,
            egress_count
        );
        ok = 0;
    }

    return ok ? 0 : 1;
}
