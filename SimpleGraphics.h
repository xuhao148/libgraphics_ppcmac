/* SimpleGraphics */
#ifndef _graphics_h
#define _graphics_h

#import <Cocoa/Cocoa.h>

#include "genlib.h"
#include "gcalloc.h"
#include "strlib.h"
#include "extgraph.h"

void InitGraphics(void);
double GetXResolution(void);
double GetYResolution(void);
void MovePen(double x, double y);
void DrawLine(double dx, double dy);
void DrawArc(double r, double start, double sweep);
double GetWindowWidth(void);
double GetWindowHeight(void);
double GetCurrentX(void);
double GetCurrentY(void);
void SGEnableMouseMoveCapture();
void SGDisableMouseMoveCapture();
void Main();
typedef enum
{
    NO_BUTTON = 0,
    LEFT_BUTTON,
    MIDDLE_BUTTON,
    RIGHT_BUTTON
} ACL_Mouse_Button;

typedef enum 
{
    BUTTON_DOWN,
    BUTTON_DOUBLECLICK,
    BUTTON_UP,
    ROLL_UP,
    ROLL_DOWN,
    MOUSEMOVE	
} ACL_Mouse_Event;

typedef enum 
{
	KEY_DOWN,
	KEY_UP
} ACL_Keyboard_Event;

typedef void (*KeyboardEventCallback) (int key,int event);
typedef void (*CharEventCallback) (char c);
typedef void (*MouseEventCallback) (int x, int y, int button, int event);
typedef void (*TimerEventCallback) (int timerID);

void registerKeyboardEvent(KeyboardEventCallback callback);
void registerCharEvent(CharEventCallback callback);
void registerMouseEvent(MouseEventCallback callback);
void registerTimerEvent(TimerEventCallback callback);

void cancelKeyboardEvent();
void cancelCharEvent();
void cancelMouseEvent();
void cancelTimerEvent();
void startTimer(int timerID, int timeinterval);

void DisplayClear();

@interface SimpleGraphics : NSObject
{
    IBOutlet id theCanvas;
    IBOutlet id theController;
    IBOutlet id theWindow;
    IBOutlet id appController;
}
- (void) actTimerFired:(int) timerID;
- (void) initVars;
- (void) actKeydown:(NSEvent *)evt;
- (void) actKeyup:(NSEvent *)evt;
- (void) actMousedown;
- (void) actMouseup;
- (void) actRightmousedown;
- (void) actRightmouseup;
- (void) actMiddlemousedown;
- (void) actMiddlemouseup;
- (void) actMousemove;
- (void) actScroll:(BOOL) up;
- (void) actModifierKey:(int)key down:(BOOL)isDown;
@end

#endif