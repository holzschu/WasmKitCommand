#import <Foundation/Foundation.h>
#include <stdio.h>
extern FILE *thread_stdin, *thread_stdout, *thread_stderr;
NSArray *environmentAsArray(void);
void initializeStreams(void);
int ios_isatty(int fd);
void ios_startInteractive(void);
void ios_stopInteractive(void);
int ios_fork(void);
int ios_system(const char *command);
int ios_waitpid(int pid);
void ios_releaseThreadId(int pid);
int ios_getCommandStatus(void);
