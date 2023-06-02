#import "AppController.h"
#include "extgraph.h"
#import "SimpleGraphics.h"

@implementation AppController

- (NSTimer *) recordAndScheduleTimer:(int)timerID interval:(double)sec {
	if (n_timers >= 64) return nil;
        else {
            int rec;
            n_timers++;
            for (rec=0;rec<64;rec++) {
                if (timers[rec].exist == NO) break;
            }
            if (rec==64) return nil;
            timers[rec].exist = YES;
            timers[rec].timerID = timerID;
            timers[rec].timerObj = [NSTimer scheduledTimerWithTimeInterval:sec
                                            target:self
                                            selector:@selector(timerFired:)
                                            userInfo:nil
                                            repeats:YES ];
            return timers[rec].timerObj;
        }
}

- (void) invalidateTimerById:(int)timerID {
    int i;
    for (i=0; i<64; i++) {
        if (timers[i].exist && timers[i].timerID == timerID) {
            NSTimer *tmr;
            tmr = timers[i].timerObj;
            [tmr invalidate];
            timers[i].exist = NO;
            timers[i].timerID = -1;
            timers[i].timerObj = nil;
            break;
        }
    }
}

- (void) timerFired:(NSTimer *)timer {
    int i;
    for (i=0; i<64; i++) {
        if (timers[i].exist && timers[i].timerObj == timer) {
            [libGraphics actTimerFired:timers[i].timerID];
            break;
        }
    }
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNote {
        int i;
        //Initialize timer entry
        n_timers = 0;
        for (i=0;i<64;i++) {
            timers[i].exist = NO;
        }
        [libGraphics initVars];
        Main();
        UpdateDisplay();
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
