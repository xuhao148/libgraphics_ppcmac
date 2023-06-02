#import "SimpleGraphics.h"
#include "extgraph.h"
#include "genlib.h"
#include "simpio.h"

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>


#include <time.h>

#include "imgui.h"


#define KMOD_SHIFT 0x01
#define KMOD_CTRL  0x02



typedef struct {
	double mousex;
	double mousey;
	int    mousedown;
	int    clickedItem;// item that was clicked
	int    actingMenu; // acting menu list 
	int    kbdItem;    // item that takes keyboard
	int    lastItem;   // item that had focus just before
	int    keyPress;   // input key
	int    charInput;  // input char
	int    keyModifiers;  //  key modifier (shift, ctrl)
} UIState;

static UIState gs_UIState;
static double  gs_menuRect[4];


static bool inBox(double x, double y, double x1, double x2, double y1, double y2)
{
	return (x >= x1 && x <= x2 && y >= y1 && y <= y2);
}

static bool notInMenu(double x, double y)
{
	return ! inBox(x, y, gs_menuRect[0], gs_menuRect[1], gs_menuRect[2], gs_menuRect[3]);
}

static void setMenuRect(double x1, double x2, double y1, double y2)
{
	gs_menuRect[0] = x1;
	gs_menuRect[1] = x2;
	gs_menuRect[2] = y1;
	gs_menuRect[3] = y2;
}


void mySetPenColor(char *color)
{
	if( color && strlen(color)>0 ) SetPenColor(color);
}



static struct {
	char frame[32];
	char label[32];
	char hotFrame[32];
	char hotLabel[32];
	int  fillflag;
} gs_predefined_colors[] = {
	{"Blue",      "Blue",	"Red",	    "Red",   0 }, // 
	{"Orange",    "Black", "Green",    "Blue",  0 }, // 
	{"Orange",    "White", "Green",    "Blue",  1 }, //
	{"Light Gray","Black",  "Dark Gray","Blue",0 },  // 
	{"Light Gray","Black",  "Dark Gray","Yellow",1 },  //
	{"Brown",     "Red",    "Orange",   "Blue",0 },
	{"Brown",     "Red",    "Orange",   "White",1 }   //
},

gs_menu_color = {
	"Blue",      "Blue",	"Red",	    "Red",   0 , //
},

gs_button_color = {
	"Blue",      "Blue",	"Red",	    "Red",   0 , //
},

gs_textbox_color = {
	"Blue",      "Blue",	"Red",	    "Red",   0 , //
};

void setButtonColors(char *frame, char*label, char *hotFrame, char *hotLabel, int fillflag)
{
	if(frame) strcpy(gs_button_color.frame, frame);
	if(label) strcpy(gs_button_color.label, label);
	if(hotFrame) strcpy(gs_button_color.hotFrame, hotFrame);
	if(hotLabel) strcpy(gs_button_color.hotLabel ,hotLabel);
	gs_button_color.fillflag = fillflag;
}

void setMenuColors(char *frame, char*label, char *hotFrame, char *hotLabel, int fillflag)
{
	if(frame) strcpy(gs_menu_color.frame, frame);
	if(label) strcpy(gs_menu_color.label, label);
	if(hotFrame) strcpy(gs_menu_color.hotFrame, hotFrame);
	if(hotLabel) strcpy(gs_menu_color.hotLabel ,hotLabel);
	gs_menu_color.fillflag = fillflag;
}

void setTextBoxColors(char *frame, char*label, char *hotFrame, char *hotLabel, int fillflag)
{
	if(frame) strcpy(gs_textbox_color.frame, frame);
	if(label) strcpy(gs_textbox_color.label, label);
	if(hotFrame) strcpy(gs_textbox_color.hotFrame, hotFrame);
	if(hotLabel) strcpy(gs_textbox_color.hotLabel ,hotLabel);
	gs_textbox_color.fillflag = fillflag;
}

void usePredefinedColors(int k)
{
	int N = sizeof(gs_predefined_colors)/sizeof(gs_predefined_colors[0]);
	gs_menu_color    = gs_predefined_colors[k%N];
	gs_button_color  = gs_predefined_colors[k%N];
	gs_textbox_color = gs_predefined_colors[k%N];
}
void usePredefinedButtonColors(int k)
{
	int N = sizeof(gs_predefined_colors)/sizeof(gs_predefined_colors[0]);
	gs_button_color  = gs_predefined_colors[k%N];
}
void usePredefinedMenuColors(int k)
{
	int N = sizeof(gs_predefined_colors)/sizeof(gs_predefined_colors[0]);
	gs_menu_color    = gs_predefined_colors[k%N];
}
void usePredefinedTexBoxColors(int k)
{
	int N = sizeof(gs_predefined_colors)/sizeof(gs_predefined_colors[0]);
	gs_textbox_color = gs_predefined_colors[k%N];
}

void InitGUI()
{
	memset(&gs_UIState, 0, sizeof(gs_UIState));
}

void uiGetMouse(int x, int y, int button, int event)
{
	 gs_UIState.mousex = ScaleXInches(x);/*pixels --> inches*/
	 gs_UIState.mousey = ScaleYInches(y);/*pixels --> inches*/

	 switch (event) {
	 case BUTTON_DOWN:
		 gs_UIState.mousedown = 1;
		 break;
	 case BUTTON_UP:
		 gs_UIState.mousedown = 0;
		 break;
	 }
}

void uiGetKeyboard(int key, int event)
{
	if( event==KEY_DOWN ) 
	{
		switch (key ) 
		{
			case 0x10:
				gs_UIState.keyModifiers |= KMOD_SHIFT;
				break;
			case 0x11:
				gs_UIState.keyModifiers |= KMOD_CTRL;
				break;
			default:
				gs_UIState.keyPress = key;
		}
	} 
	else if( event==KEY_UP )
	{
		switch (key ) 
		{
			case 0x10:
				gs_UIState.keyModifiers &= ~KMOD_SHIFT;
				break;
			case 0x11:
				gs_UIState.keyModifiers &= ~KMOD_CTRL;
				break;
			default:
				gs_UIState.keyPress = 0;
		}
	}
}

void uiGetChar(int ch)
{
	gs_UIState.charInput = ch;
}


int button(int id, double x, double y, double w, double h, char *label)
{
	char * frameColor = gs_button_color.frame;
	char * labelColor = gs_button_color.label;
	double movement = 0.2*h;
	double shrink = 0.15*h;
	double sinkx = 0, sinky = 0;
	//int isHotItem = 0;

	if (notInMenu(gs_UIState.mousex, gs_UIState.mousey) &&
		inBox(gs_UIState.mousex, gs_UIState.mousey, x, x + w, y, y + h)) 
	{
		static int timesss = 0; timesss++;
		printf("%d not in %f %f %f %f\n", timesss, gs_menuRect[0], gs_menuRect[1], gs_menuRect[2], gs_menuRect[3]);
		frameColor = gs_button_color.hotFrame;
		labelColor = gs_button_color.hotLabel;
		gs_UIState.actingMenu = 0; // menu lose focus
		if ( gs_UIState.mousedown) {
			gs_UIState.clickedItem = id;
			sinkx =   movement;
			sinky = - movement;
		}
	}
	else {
		if ( gs_UIState.clickedItem==id )
			gs_UIState.clickedItem = 0;
	}

	// If no widget has keyboard focus, take it
	if (gs_UIState.kbdItem == 0)
		gs_UIState.kbdItem = id;
	// If we have keyboard focus, we'll need to process the keys
	if ( gs_UIState.kbdItem == id && gs_UIState.keyPress==0x09 ) 
	{
		// If tab is pressed, lose keyboard focus.
		// Next widget will grab the focus.
		gs_UIState.kbdItem = 0;
		// If shift was also pressed, we want to move focus
		// to the previous widget instead.
		if ( gs_UIState.keyModifiers & KMOD_SHIFT )
			gs_UIState.kbdItem = gs_UIState.lastItem;
		gs_UIState.keyPress = 0;
	}
	gs_UIState.lastItem = id;

	// draw the button
	mySetPenColor(frameColor);
	drawBox(x+sinkx, y+sinky, w, h, gs_button_color.fillflag,
		label, 'C', labelColor);
	if( gs_button_color.fillflag ) {
		mySetPenColor( labelColor );
		drawRectangle(x+sinkx, y+sinky, w, h, 0);
	}

	// show a small ractangle frane
	if( gs_UIState.kbdItem == id ) {
		mySetPenColor( labelColor );
		drawRectangle(x+sinkx+shrink, y+sinky+shrink, w-2*shrink, h-2*shrink, 0);
	}

	if( gs_UIState.clickedItem==id && // must be clicked before
		! gs_UIState.mousedown )   // but now mouse button is up
	{
		gs_UIState.clickedItem = 0;
		gs_UIState.kbdItem = id;
		return 1; 
	}

	return 0;
}

static int menuItem(int id, double x, double y, double w, double h, char *label)
{
	char * frameColor = gs_menu_color.frame;
	char * labelColor = gs_menu_color.label;
	if (inBox(gs_UIState.mousex, gs_UIState.mousey, x, x + w, y, y + h)) {
		frameColor = gs_menu_color.hotFrame;
		labelColor = gs_menu_color.hotLabel;
		//if (gs_UIState.mousedown) {
		if ( (gs_UIState.clickedItem == id ||gs_UIState.clickedItem == 0) && gs_UIState.mousedown) {
			gs_UIState.clickedItem = id;
		}
	}
	else {
		if ( gs_UIState.clickedItem==id )
			gs_UIState.clickedItem = 0;
	}

	mySetPenColor(frameColor);
	drawBox(x, y, w, h, gs_menu_color.fillflag, label, 'L', labelColor);

	if( gs_UIState.clickedItem==id && // must be clicked before
		! gs_UIState.mousedown )     // but now mouse button is up
	{
		gs_UIState.clickedItem = 0;
		return 1; 
	}

	return 0;
}

static char ToUpperLetter(char c)
{
	return (c>='a' && c<='z' ? c-'a'+'A' : c);
}

static char shortcutkey(char *s)
{
	char predStr[] = "Ctrl-";
	int M = strlen(predStr)+1;
	int n = s ? strlen(s) : 0;

	if( n<M || strncmp(s+n-M, predStr, M-1)!=0 )
		return 0;

	return ToUpperLetter(s[n-1]);
}

int menuList(int id, double x, double y, double w, double wlist, double h, char *labels[], int n)
{
	static int unfoldMenu = 0;
	int result = 0;
	int k = -1;


	if( gs_UIState.keyModifiers & KMOD_CTRL ) {
		for( k=1; k<n; k++ ) {
			int kp = ToUpperLetter( gs_UIState.keyPress );
			if( kp && kp == shortcutkey(labels[k]) ) {
				gs_UIState.keyPress = 0;
				break;
			}
		}
	}

	if( k>0 && k<n ) 
	{	
		unfoldMenu = 0;
		return k; 
	}



	if( inBox(gs_UIState.mousex, gs_UIState.mousey, x, x + w, y, y + h) )
		gs_UIState.actingMenu = id;

	if( menuItem(id, x, y, w, h, labels[0]) )
		unfoldMenu = ! unfoldMenu;

	if( gs_UIState.actingMenu == id && unfoldMenu  ) {
		int k;
		gs_UIState.charInput = 0; // disable text editing
		gs_UIState.keyPress = 0;  // disable text editing
		setMenuRect(x, x + wlist, y - n * h + h, y);
		for( k=1; k<n; k++ ) {
			if ( menuItem(GenUIID(k)+id, x, y-k*h, wlist, h, labels[k]) ) {
				unfoldMenu = 0;
				setMenuRect(0, 0, 0, 0);
				result = k;
			}
		}
	}
	return result;
}

void drawMenuBar(double x, double y, double w, double h)
{
	mySetPenColor(gs_menu_color.frame);
        NSLog(@"Menu loc. %lf,%lf %lfx%lf",x,y,w,h);
	drawRectangle(x,y,w,h,gs_menu_color.fillflag);
}


int textbox(int id, double x, double y, double w, double h, char textbuf[], int buflen)
{
	char * frameColor = gs_textbox_color.frame;
	char * labelColor = gs_textbox_color.label;
	int textChanged = 0;
	int len = strlen(textbuf);
	double indent = GetFontAscent()/2;
	double textPosY = y+h/2-GetFontAscent()/2;

	if (notInMenu(gs_UIState.mousex, gs_UIState.mousey) &&
		inBox(gs_UIState.mousex, gs_UIState.mousey, x, x + w, y, y + h) ) 
	{
		frameColor = gs_textbox_color.hotFrame;
		labelColor = gs_textbox_color.hotLabel;
		gs_UIState.actingMenu = 0; // menu lose focus
		if ( gs_UIState.mousedown) {
			gs_UIState.clickedItem = id;
		}
	}

	// If no widget has keyboard focus, take it
	if (gs_UIState.kbdItem == 0)
		gs_UIState.kbdItem = id;

	if (gs_UIState.kbdItem == id)
		labelColor = gs_textbox_color.hotLabel;

	// Render the text box
	mySetPenColor(frameColor);
	drawRectangle(x, y, w, h, gs_textbox_color.fillflag);
	// show text
	mySetPenColor(labelColor);
	MovePen(x+indent, textPosY);
	DrawTextString(textbuf);
	// add cursor if we have keyboard focus
	if ( gs_UIState.kbdItem == id && (clock() >> 8) & 1) 
	{
		//MovePen(x+indent+TextStringWidth(textbuf), textPosY);
		DrawTextString("_");
	}

	// If we have keyboard focus, we'll need to process the keys
	if ( gs_UIState.kbdItem == id )
	{
		switch (gs_UIState.keyPress)
		{
		case 0x0D:
		case 0x09:
			// lose keyboard focus.
			gs_UIState.kbdItem = 0;
			// If shift was also pressed, we want to move focus
			// to the previous widget instead.
			if ( gs_UIState.keyModifiers & KMOD_SHIFT )
				gs_UIState.kbdItem = gs_UIState.lastItem;
			// Also clear the key so that next widget won't process it
			gs_UIState.keyPress = 0;
			break;
		case 0x08:
			if( len > 0 ) {
				textbuf[--len] = 0;
				textChanged = 1;
			}
			gs_UIState.keyPress = 0;
			break;
		}
		// char input
		if (gs_UIState.charInput >= 32 && gs_UIState.charInput < 127 && len+1 < buflen ) {
			textbuf[len] = gs_UIState.charInput;
			textbuf[++len] = 0;
			gs_UIState.charInput = 0;
			textChanged = 1;
		}
	}

	gs_UIState.lastItem = id;

	if( gs_UIState.clickedItem==id && // must be clicked before
		! gs_UIState.mousedown )     // but now mouse button is up
	{
		gs_UIState.clickedItem = 0;
		gs_UIState.kbdItem = id;
	}

	return textChanged;
}


void drawRectangle(double x, double y, double w, double h, int fillflag)
{
	MovePen(x, y);
	if( fillflag ) StartFilledRegion(1); 
	{
		DrawLine(0, h);
		DrawLine(w, 0);
		DrawLine(0, -h);
		DrawLine(-w, 0);
	}
	if( fillflag ) EndFilledRegion();
}

void drawBox(double x, double y, double w, double h, int fillflag, char *label, char labelAlignment, char *labelColor)
{
	double fa = GetFontAscent();
	// rect
	drawRectangle(x,y,w,h,fillflag);
	// text
	if( label && strlen(label)>0 ) {
		mySetPenColor(labelColor);
		if( labelAlignment=='L' )
			MovePen(x+fa/2, y+h/2-fa/2);
		else if( labelAlignment=='R' )
			MovePen(x+w-fa/2-TextStringWidth(label), y+h/2-fa/2);
		else // if( labelAlignment=='C'
			MovePen(x+(w-TextStringWidth(label))/2, y+h/2-fa/2);
		DrawTextString(label);
	}
}

void drawLabel(double x, double y, char *label)
{
	if( label && strlen(label)>0 ) {
		MovePen(x,y);
		DrawTextString(label);
	}
}