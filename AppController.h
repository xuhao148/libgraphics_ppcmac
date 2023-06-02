/* AppController */

#import <Cocoa/Cocoa.h>
#import "SimpleGraphics.h"

typedef struct {
    BOOL exist;
    int timerID;
    id timerObj;
} SGTimerEntryT;
extern void Main();
@interface AppController : NSObject
{
    IBOutlet id gwControl;
    IBOutlet id libGraphics;
    IBOutlet id theCanvas;
    IBOutlet id theWindow;
    SGTimerEntryT timers[64];
    int n_timers;
}
- (NSTimer *) recordAndScheduleTimer:(int)timerID interval:(double)sec;
- (void) timerFired:(NSTimer *)timer;
- (void) invalidateTimerById:(int)timerID;
@end
