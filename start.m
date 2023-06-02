
#import "SimpleGraphics.h"
#include "extgraph.h"
#include "genlib.h"
#include "simpio.h"

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>


#include "imgui.h"

#include "hanoi.h"

#define MOVE_DISC  1


static double winwidth, winheight;
static int    enable_move_disc = 1;
static int    timer_interval = 2;
static char   time_elapse_speed[64];

void SetSpeedEditString(double speed)
{
	sprintf(time_elapse_speed, "%f", speed);
}
double GetEditTimeSpeed()
{
	double v = 0;
	sscanf(time_elapse_speed, "%lf", &v);
	return v;
}

void DisplayClear(void); 

void startTimer(int id,int timeinterval);

void display(void); 

void CharEventProcess(char ch)
{
	uiGetChar(ch);
	display();
}

void KeyboardEventProcess(int key, int event)
{
	uiGetKeyboard(key,event);
	display();
}

void MouseEventProcess(int x, int y, int button, int event)
{
	uiGetMouse(x,y,button,event);
	display();
}

void TimerEventProcess(int timerID)
{
	if( timerID==MOVE_DISC && enable_move_disc ) 
	{
		int s = OneStepHanoi();
	}
	display();
}

void Main() 
{

	SetWindowTitle("Hanoi Demo");
	SetWindowSize(10, 8);
    InitGraphics();

    winwidth = GetWindowWidth();
    winheight = GetWindowHeight();
        SGEnableMouseMoveCapture();
	registerCharEvent(CharEventProcess);
	registerKeyboardEvent(KeyboardEventProcess);
	registerMouseEvent(MouseEventProcess); 
	registerTimerEvent(TimerEventProcess);

	startTimer(MOVE_DISC, timer_interval);

	InitTower(6);
	SetSpeedEditString(GetHanoiTimeElapseSpeed());
}

void DrawMenu()
{
	static char * menuListFile[] = {"File",  
		"Restart  | Ctrl-R",
		"Exit            | Ctrl-E"};
	static char * menuListTool[] = {"Tool",
		"Pause    | Ctrl-T"};
	static char * menuListHelp[] = {"Help",
		"About"};

	double fH = GetFontHeight();
	double x = 0;
	double y = winheight;
	double h = fH*1.5;
	double w = TextStringWidth(menuListFile[0])*2;
	double wlist = TextStringWidth(menuListFile[1])*1.2;
	double xindent = winheight/20;
	int    selection;
	//NSLog(@"Drawing Menu Bar");
	drawMenuBar(0,y-h-0.3,winwidth,h);
        //NSLog(@"Menubar drawn");
	selection = menuList(GenUIID(0), x, y-h-0.3, w, wlist, h, menuListFile, sizeof(menuListFile)/sizeof(menuListFile[0]));
	if( selection==2 )
		exit(-1);
	else if( selection==1 )
	{
		InitTower(g_disc_count);
	}
	
	menuListTool[1] = enable_move_disc ? "’â‰æ   |   Ctrl-T" : "‰æ   |   Ctrl-T";
	selection = menuList(GenUIID(0),x+w,  y-h-0.3, w, wlist,h, menuListTool,sizeof(menuListTool)/sizeof(menuListTool[0]));
	if( selection==1 )
		enable_move_disc = ! enable_move_disc;
	
	selection = menuList(GenUIID(0),x+2*w,y-h-0.3, w, wlist, h, menuListHelp,sizeof(menuListHelp)/sizeof(menuListHelp[0]));
	if( selection==1 ) {
		//TODO
	}
}

void DrawButtons()
{
	double fH = GetFontHeight();
	double h = fH*2; 
	double x = winwidth/4;  
	double y = winheight/4; 
	double w = TextStringWidth("Pause")*3;
	double dx = w + TextStringWidth("e");
	double dy = h * 2;

	drawLabel(x,y+dy,"Speed");
	if( textbox(GenUIID(0), x+dx*0.7, y+dy*0.8, w, h, time_elapse_speed, sizeof(time_elapse_speed) ) )
		SetHanoiTimeElapseSpeed( GetEditTimeSpeed() );

	if( button(GenUIID(0), x+dx*1.7, y+dy*0.8, w, h, "Add Disc") ) {
		InitTower(g_disc_count + 1);
	}
	if( button(GenUIID(0), x+dx*2.7, y+dy*0.8, w, h, "Remove Disc") ) {
		InitTower(g_disc_count - 1);
	}

	if( button(GenUIID(0), x, y-=dy, w, h, "Reset") ) {
		InitTower(g_disc_count);
	}

	if( button(GenUIID(0), x+=dx, y, w, h, enable_move_disc ? "Pause" : "Cont") ) {	
		enable_move_disc = ! enable_move_disc;
	}

	if( button(GenUIID(0), x+=dx, y, w, h, "Quit") ) {	
		exit(-1); 
	}
	if( button(GenUIID(0), x+=dx, y, w, h, "Speed Up") ) {	
		SetHanoiTimeElapseSpeed( GetHanoiTimeElapseSpeed()*1.5 );
		SetSpeedEditString( GetHanoiTimeElapseSpeed() );
	}
	if( button(GenUIID(0), x+=dx, y, w, h, "Speed Down") ) {
		SetHanoiTimeElapseSpeed( GetHanoiTimeElapseSpeed()*0.7 );
		SetSpeedEditString( GetHanoiTimeElapseSpeed() );
	}
}

void display()
{

	DisplayClear();

	DrawHanoi(winwidth, winheight);

	DrawMenu();
	DrawButtons();
}
