#import "ios_system.h"
#include <termios.h>
#include <unistd.h>
FILE *thread_stdin, *thread_stdout, *thread_stderr;
void initializeStreams(void) {
    thread_stdin = stdin;
    thread_stdout = stdout;
    thread_stderr = stderr;
}
NSArray *environmentAsArray(void) {
    NSDictionary *environment = NSProcessInfo.processInfo.environment;
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *key in environment) {
        [result addObject:[NSString stringWithFormat:@"%@=%@", key, environment[key]]];
    }
    return result;
}
int ios_isatty(int fd) { return isatty(fd); }
// Stand-in for a-Shell's direct keyboard mode: the host terminal goes raw, so the
// test can observe it from the pty's other end.
static struct termios saved_termios;
static int interactive;
void ios_startInteractive(void) {
    if (interactive || tcgetattr(STDIN_FILENO, &saved_termios) != 0) return;
    struct termios raw = saved_termios;
    cfmakeraw(&raw);
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    interactive = 1;
}
void ios_stopInteractive(void) {
    if (!interactive) return;
    tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
    interactive = 0;
}
// This test exercises Preview1 stdio/filesystem, never a-Shell command dispatch.
int ios_fork(void) { abort(); }
int ios_system(const char *command) { abort(); }
int ios_waitpid(int pid) { abort(); }
void ios_releaseThreadId(int pid) { abort(); }
int ios_getCommandStatus(void) { abort(); }
