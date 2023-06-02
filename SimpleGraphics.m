#import "SimpleGraphics.h"
#import "GraphicView.h"
#import "GWController.h"
#import "AppController.h"
#import "macaux.h"

//Additional vars for Mac OS X Port
GraphicView *canvasobj;
GWController *controllerobj;
NSWindow *windowobj;
AppController *appctrlobj;
SimpleGraphics *selfobj;

NSFont *lgCurrentFont;
int win_width;
int win_height;
int timer_count = 0;

KeyboardEventCallback g_keyboard = NULL;
MouseEventCallback g_mouse = NULL;
TimerEventCallback g_timer = NULL;
CharEventCallback g_char = NULL;

#define DesiredWidth       10.0
#define DesiredHeight      7.0
#define DefaultSize       12
#define MaxFonts         100
#define LeftMargin        0/*10*/
#define RightMargin       25
#define TopMargin          0
#define BottomMargin      30
#define PStartSize        50
#define MaxColors        256
#define MinColors         16
#define MaxFontName	256

#define GWClassName "Graphics Window"
#define DefaultFont "Lucida Grande"

/*
 * Other constants
 * ---------------
 * LargeInt  -- Integer too large for a coordinate value
 * Epsilon   -- Small arithmetic offset to reduce aliasing/banding
 * Pi        -- Mathematical constant pi
 * AnyButton -- Union of all mouse buttons
 */

#define LargeInt 16000
#define Epsilon  0.00000000001
#define Pi       3.1415926535

/*
 * Type: graphicsStateT
 * --------------------
 * This structure holds the variables that make up the graphics state.
 */

typedef struct graphicsStateT {
    double cx, cy;
    string font;
    int size;
    int style;
    bool erase;
    int color;
    struct graphicsStateT *link;
} *graphicsStateT;

/*
 * Type: fontEntryT
 * ----------------
 * This structure holds the data for a font.
 */

typedef struct {
    string name;
    int size, style;
    int points, ascent, descent, height;
    NSFont *font;
} fontEntryT;

/*
 * Type: regionStateT
 * ------------------
 * The region assembly process has the character of a finite state
 * machine with the following four states:
 *
 *   NoRegion       Region has not yet been started
 *   RegionStarting Region is started but no line segments yet
 *   RegionActive   First line segment appears
 *   PenHasMoved    Pen has moved during definition
 *
 * The current state determines whether other operations are legal
 * at that point.
 */

typedef enum {
    NoRegion, RegionStarting, RegionActive, PenHasMoved
} regionStateT;

/*
 * Type: colorEntryT
 * -----------------
 * This type is used for the entries in the color table.
 */

typedef struct {
    string name;
    double red, green, blue;
} colorEntryT;

/*
 * Static table: fillList
 * ----------------------
 * This table contains the bitmap patterns for the various density
 * values.  Adding more patterns to this list increases the
 * precision with which the client can control fill patterns.
 * Note that this bitmap is inverted from that used on most
 * systems, with 0 indicating foreground and 1 indicating background.
 */
 
 static short fillList[][8] = {
    { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    { 0x77, 0xDD, 0x77, 0xDD, 0x77, 0xDD, 0x77, 0xDD },
    { 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA },
    { 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22 },
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
};

#define NFills (sizeof fillList / sizeof fillList[0])

static int penSize = 1;

static bool initialized = FALSE;
static bool pauseOnExit = TRUE;

NSImage *osim; // Replaces osdc
static NSColor *drawColor, *eraseColor;
static NSColor *currentColor;
static string windowTitle = "Graphics Window";

static double xResolution, yResolution;
static double windowWidth = DesiredWidth;
static double windowHeight = DesiredHeight;
static int pixelWidth, pixelHeight;

static fontEntryT fontTable[MaxFonts];
static int nFonts;
static int currentFont;

static regionStateT regionState;
static double regionDensity;
static NSPoint *polygonPoints;
static int nPolygonPoints;
static int polygonSize;
static NSRect polygonBounds;
//static HBITMAP fillBitmaps[NFills];

static colorEntryT colorTable[MaxColors];
static int nColors;
static int previousColor;

static graphicsStateT stateStack;

static double cx, cy;
static BOOL eraseMode;
static string textFont;
static int textStyle;
static int pointSize;
static int penColor;

static int mouseX, mouseY;
static BOOL mouseButton = NO;

/* Private function prototypes */

static void InitCheck(void);
static void InitGraphicsState(void);
static void InitDisplay(void);
static void InitDrawingTools(void);
static void DisplayExit(void);
//static HWND FindConsoleWindow(void);
//static BOOL CALLBACK EnumerateProc(HWND window, LPARAM clientData);
static void RegisterWindowClass(void);
//static LONG FAR PASCAL GraphicsEventProc(HWND w, UINT msg, WPARAM p1, LPARAM p2);
//static void CheckEvents(void);
static void DoUpdate(void);
void DisplayClear(void);
static void PrepareToDraw(void);
static void DisplayLine(double x, double y, double dx, double dy);
static void DisplayArc(double xc, double yc, double rx, double ry,
                       double start, double sweep);
static void RenderArc(double x, double y, double rx, double ry,
                      double start, double sweep);
static void DisplayText(double x, double y, string text);
static void DisplayFont(string font, int size, int style);
static int FindExistingFont(string name, int size, int style);
static void SetLineBB(NSRect *rp, double x, double y, double dx, double dy);
static void SetArcBB(NSRect *rp, double xc, double yc,
                     double rx, double ry, double start, double sweep);
static void SetTextBB(NSRect *rp, double x, double y, string text);
void LGSetRect(NSRect *rp, double ix, double iy, double width, double height);
static void StartPolygon(void);
static void AddSegment(int x0, int y0, int x1, int y1);
static void DisplayPolygon(void);
static void AddPolygonPoint(int x, int y);
static void InitColors(void);
static int FindColorName(string name);

static BOOL StringMatch(string s1, string s2);
static BOOL PrefixMatch(string prefix, string str);
static int RectWidth(NSRect *rp);
static int RectHeight(NSRect *rp);
static void LGSetRectFromSize(NSRect *rp, int x, int y, int width, int height);
static double Radians(double degrees);
static int Round(double x);
static double InchesX(int x);
static double InchesY(int y);
static int PixelsX(double x);
static int PixelsY(double y);
static int ScaleX(double x);
static int ScaleY(double y);
static int Min(int x, int y);
static int Max(int x, int y);

/* Exported entries */

/* Section 1 -- Basic functions from graphics.h */

void InitGraphics(void)
{
    if (!initialized) {
        initialized = YES;
        //ProtectVariable(stateStack);
        //ProtectVariable(windowTitle);
        //ProtectVariable(textFont);
        InitColors();
        NSLog(@"Initting display");
        InitDisplay();
        NSLog(@"InitDisplay done");
    }
    NSLog(@"Clearing display");
    DisplayClear();
    NSLog(@"DisplayClear done");
    InitGraphicsState();
    NSLog(@"Initialization all done");
}

void MovePen(double x, double y)
{
    InitCheck();
    if (regionState == RegionActive) regionState = PenHasMoved;
    cx = x;
    cy = y;
}

void DrawLine(double dx, double dy)
{
    InitCheck();
    switch (regionState) {
      case NoRegion:
        DisplayLine(cx, cy, dx, dy);
        break;
      case RegionStarting: case RegionActive:
        DisplayLine(cx, cy, dx, dy);
        regionState = RegionActive;
        break;
      case PenHasMoved:
        Error("Region segments must be contiguous");
    }
    cx += dx;
    cy += dy;
}

void DrawArc(double r, double start, double sweep)
{
    DrawEllipticalArc(r, r, start, sweep);
}

double GetWindowWidth(void)
{
    InitCheck();
    return (windowWidth);
}

double GetWindowHeight(void)
{
    InitCheck();
    return (windowHeight);
}

double GetCurrentX(void)
{
    InitCheck();
    return (cx);
}

double GetCurrentY(void)
{
    InitCheck();
    return (cy);
}

/* Section 2 -- Elliptical arcs */

void DrawEllipticalArc(double rx, double ry,
                       double start, double sweep)
{
    double x, y;

    InitCheck();
    x = cx + rx * cos(Radians(start + 180));
    y = cy + ry * sin(Radians(start + 180));
    switch (regionState) {
      case NoRegion:
        DisplayArc(x, y, rx, ry, start, sweep);
        break;
      case RegionStarting: case RegionActive:
        RenderArc(x, y, rx, ry, start, sweep);
        regionState = RegionActive;
        break;
      case PenHasMoved:
        Error("Region segments must be contiguous");
    }
    cx = x + rx * cos(Radians(start + sweep));
    cy = y + ry * sin(Radians(start + sweep));
}

/* Section 3 -- Graphical structures */

void StartFilledRegion(double grayScale)
{
    InitCheck();
    if (regionState != NoRegion) {
        Error("Region is already in progress");
    }
    if (grayScale < 0 || grayScale > 1) {
        Error("Gray scale for regions must be between 0 and 1");
    }
    regionState = RegionStarting;
    regionDensity = grayScale;
    StartPolygon();
}

void EndFilledRegion(void)
{
    InitCheck();
    if (regionState == NoRegion) {
        Error("EndFilledRegion without StartFilledRegion");
    }
    DisplayPolygon();
    regionState = NoRegion;
}

/* Section 4 -- String functions */

void DrawTextString(string text)
{
    InitCheck();
    if (regionState != NoRegion) {
        Error("Text strings are illegal inside a region");
    }
    DisplayText(cx, cy, text);
    cx += TextStringWidth(text);
}

double TextStringWidth(string text)
{
    NSRect r;

    InitCheck();
    SetTextBB(&r, cx, cy, text);
    return (InchesX(RectWidth(&r)));
}

void SetFont(string font)
{
    InitCheck();
    DisplayFont(font, pointSize, textStyle);
}

string GetFont(void)
{
    InitCheck();
    return (CopyString(textFont));
}

void SetPointSize(int size)
{
    InitCheck();
    DisplayFont(textFont, size, textStyle);
}

int GetPointSize(void)
{
    InitCheck();
    return (pointSize);
}

void SetStyle(int style)
{
    InitCheck();
    DisplayFont(textFont, pointSize, style);
}

int GetStyle(void)
{
    InitCheck();
    return (textStyle);
}

double GetFontAscent(void)
{
    InitCheck();
    return (InchesY(fontTable[currentFont].ascent));
}

double GetFontDescent(void)
{
    InitCheck();
    return (InchesY(fontTable[currentFont].descent));
}

double GetFontHeight(void)
{
    InitCheck();
    return (InchesY(fontTable[currentFont].height));
}

/* Section 5 -- Mouse support */

double GetMouseX(void)
{
    InitCheck();
    //CheckEvents();
    return (InchesX([NSEvent mouseLocation].x));
}

double GetMouseY(void)
{
    InitCheck();
    //CheckEvents();
    return (InchesY([NSEvent mouseLocation].y));
}

BOOL MouseButtonIsDown(void)
{
    InitCheck();
    //CheckEvents();
    return mouseButton;
}

/*

These two are too hard for me to implement.
Since the original library didn't implement them, I won't either.


void WaitForMouseDown(void)
{
    MSG msg;

    UpdateDisplay();
    while (!mouseButton) {
        if (GetMessage(&msg, graphicsWindow, 0, 0) == 0) exit(0);
        DispatchMessage(&msg);
    }
    //while (!mouseButton);
}

void WaitForMouseUp(void)
{
    MSG msg;

    UpdateDisplay();
    while (mouseButton) {
        if (GetMessage(&msg, graphicsWindow, 0, 0) == 0) exit(0);
        DispatchMessage(&msg);
    }
    //while (mouseButton);
}

*/

BOOL HasColor(void)
{
    InitCheck();
    return YES; // Mac OS X devices all have colors
}

void SetPenColor(string color)
{
    int cindex;

    InitCheck();
    cindex = FindColorName(color);
    if (cindex == -1) Error("Undefined color: %s", color);
    penColor = cindex;
}

string GetPenColor(void)
{
    InitCheck();
    return (CopyString(colorTable[penColor].name));
}

void DefineColor(string name,
                 double red, double green, double blue)
{
    int cindex;

    InitCheck();
    if (red < 0 || red > 1 || green < 0 || green > 1 || blue < 0 || blue > 1) {
        Error("DefineColor: All color intensities must be between 0 and 1");
    }
    cindex = FindColorName(name);
    if (cindex == -1) {
        if (nColors == MaxColors) Error("DefineColor: Too many colors");
        cindex = nColors++;
    }
    colorTable[cindex].name = CopyString(name);
    colorTable[cindex].red = red;
    colorTable[cindex].green = green;
    colorTable[cindex].blue = blue;
}

/* Section 7 -- Miscellaneous functions */

void SetPenSize(int size)
{
    penSize = size;
}

int GetPenSize(void)
{
 	return penSize;
}

void SetEraseMode(BOOL mode)
{
    InitCheck();
    eraseMode = mode;
}

bool GetEraseMode(void)
{
    InitCheck();
    return (eraseMode);
}

void SetWindowTitle(string title)
{
    windowTitle = CopyString(title);
    if (initialized) {
        [[canvasobj window] setTitle:[[NSString alloc] initWithCString:windowTitle]];
    }
}

string GetWindowTitle(void)
{
    return (CopyString(windowTitle));
}

void UpdateDisplay(void)
{
    InitCheck();
    //CheckEvents();
    DoUpdate();
}

void Pause(double seconds)
{
    UpdateDisplay();
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

void ExitGraphics(void)
{
    pauseOnExit = NO;
    exit(0);
}

void SaveGraphicsState(void)
{
    graphicsStateT sb;

    InitCheck();
    sb = New(graphicsStateT);
    sb->cx = cx;
    sb->cy = cy;
    sb->font = textFont;
    sb->size = pointSize;
    sb->style = textStyle;
    sb->erase = eraseMode;
    sb->color = penColor;
    sb->link = stateStack;
    stateStack = sb;
}

void RestoreGraphicsState(void)
{
    graphicsStateT sb;

    InitCheck();
    if (stateStack == NULL) {
        Error("RestoreGraphicsState called before SaveGraphicsState");
    }
    sb = stateStack;
    cx = sb->cx;
    cy = sb->cy;
    textFont = sb->font;
    pointSize = sb->size;
    textStyle = sb->style;
    eraseMode = sb->erase;
    penColor = sb->color;
    DisplayFont(textFont, pointSize, textStyle);
    stateStack = sb->link;
    FreeBlock(sb);
}

double GetFullScreenWidth(void)
{
	NSDictionary *desc = [[NSScreen mainScreen] deviceDescription];
	NSValue *ds = [desc objectForKey:NSDeviceSize];
	NSSize dss = [ds sizeValue];
	return ((double) dss.width / GetXResolution());
}

double GetFullScreenHeight(void)
{
	NSDictionary *desc = [[NSScreen mainScreen] deviceDescription];
	NSValue *ds = [desc objectForKey:NSDeviceSize];
	NSSize dss = [ds sizeValue];
	return ((double) dss.height / GetYResolution());
}

void SetWindowSize(double width, double height)
{
    if (initialized) return;
    windowWidth = width;
    windowHeight = height;
}

double GetXResolution(void)
{
	int xdpi; NSDictionary *desc; NSValue *dpi; NSSize dpis;
    desc = [[NSScreen mainScreen] deviceDescription];
    dpi = [desc objectForKey:NSDeviceResolution];
    dpis = [dpi sizeValue];
    xdpi = dpis.width;
    NSLog(@"Got XDpi %d",xdpi);
    return (xdpi);
}

double GetYResolution(void)
{
    int xdpi,ydpi;
    NSDictionary *desc = [[NSScreen mainScreen] deviceDescription];
    NSValue *dpi = [desc objectForKey:NSDeviceResolution];
    NSSize dpis = [dpi sizeValue];
    ydpi = dpis.height;
    NSLog(@"Got YDpi %d",ydpi);
    return (ydpi);
}

/* Private functions */

/*
 * Function: InitCheck
 * Usage: InitCheck();
 * -------------------
 * This function merely ensures that the package has been
 * initialized before the client functions are called.
 */

static void InitCheck(void)
{
    if (!initialized) Error("InitGraphics has not been called");
}

/*
 * Function: InitGraphicsState
 * Usage: InitGraphicsState();
 * ---------------------------
 * This function initializes the graphics state elements to
 * their default values.  Because the erase mode and font
 * information are also maintained in the display state,
 * InitGraphicsState must call functions to ensure that these
 * values are initialized there as well.
 */

static void InitGraphicsState(void)
{
    cx = cy = 0;
    eraseMode = FALSE;
    textFont = "Lucida Grande";
    pointSize = DefaultSize;
    textStyle = Normal;
    stateStack = NULL;
    regionState = NoRegion;
    DisplayFont(textFont, pointSize, textStyle);
}

// repaint() omitted for no actual use

static void InitDisplay(void)
{
    NSRect bounds, consoleRect, graphicsRect;
    double screenHeight, screenWidth, xSpace, ySpace;
    double xScale, yScale, scaleFactor;
    int top, dx, dy, cWidth;
	
	//atexit(DisplayExit);
	initialized = NO;
	xResolution = GetXResolution();
    yResolution = GetYResolution();
    initialized = YES;
    screenWidth = GetFullScreenWidth();
    screenHeight = GetFullScreenHeight();
    xSpace = screenWidth - InchesX(LeftMargin + RightMargin);
    ySpace = screenHeight - InchesX(TopMargin + BottomMargin);
    xScale = yScale = 1.0;
    if (windowWidth > xSpace) xScale = xSpace / windowWidth;
    if (windowHeight > ySpace) yScale = ySpace / windowHeight;
    scaleFactor = (xScale < yScale) ? xScale : yScale;
    cWidth = PixelsX(DesiredWidth * scaleFactor);
    xResolution *= scaleFactor;
    yResolution *= scaleFactor;
    
    LGSetRectFromSize(&graphicsRect, LeftMargin, BottomMargin,
                    PixelsX(windowWidth), PixelsY(windowHeight));
	//style equivalent defined in Nib file
	
	g_keyboard = NULL;
	g_mouse = NULL;
	g_timer = NULL;
	
        NSLog(@"Decided window frame (%lf,%lf) size %lf x %lf",graphicsRect.origin.x,graphicsRect.origin.y,graphicsRect.size.width,graphicsRect.size.height);
        
	//CreateWindow equivalent
	[windowobj setTitle:[[NSString alloc] initWithCString:windowTitle]];
	[windowobj setFrame:graphicsRect display:YES];
	//also change the size of our NSView!
	[canvasobj setFrameOrigin:NSMakePoint(0,0)];
	[canvasobj setFrameSize:graphicsRect.size];
	win_width = graphicsRect.size.width;
	win_height = graphicsRect.size.height;
	//show it.
	[controllerobj showWindow:selfobj];
        [[canvasobj window] makeKeyAndOrderFront:nil];
	[[canvasobj window] makeFirstResponder:canvasobj];
        
	//create osim.
	osim = [[[NSImage alloc] initWithSize:graphicsRect.size] retain];
	if (osim == nil) {
            Error("Internal error: Can't create offscreen NSImage object");
	} else {
            NSLog(@"Successfully generated offscreen NSImage");
        }
	[osim lockFocus];
	[[NSGraphicsContext currentContext] saveGraphicsState];
        NSLog(@"Focus locked & graphicsState saved");
	[[NSColor whiteColor] set];
	NSRectFill(NSMakeRect(0,0,graphicsRect.size.width,graphicsRect.size.height));
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	[osim unlockFocus];
        NSLog(@"Focus unlocked");
	//draw for the first time
	[canvasobj lockFocus];
        NSLog(@"Attempting to put it onto the canvas");
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[osim drawAtPoint:NSMakePoint(0,0) fromRect:NSZeroRect
			operation: NSCompositeCopy fraction:1];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	[canvasobj unlockFocus];
        NSLog(@"Putting onto canvas done");
	InitDrawingTools();
}

// WE ARE HERE...
/*
 * Function: InitDrawingTools
 * Usage: InitDrawingTools();
 * --------------------------
 * This function initializes all of the standard objects used for
 * drawing except for fonts, which are initialized dynamically by
 * the DisplayFont procedure.  This function creates the
 * foreground/background colors, the drawing pens, and the brushes
 * for filled regions.
 */

static void InitDrawingTools(void)
{
    int i;

    nFonts = 0;
    previousColor = 0;
    drawColor = [[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1] retain];
    eraseColor = [[NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1] retain];
    /*
    drawPen = (HPEN) CreatePen(PS_SOLID, penSize, drawColor);
    erasePen = (HPEN) CreatePen(PS_SOLID, penSize, eraseColor);
    nullPen = (HPEN) GetStockObject(NULL_PEN);
    if (drawPen == NULL || erasePen == NULL || nullPen == NULL) {
        Error("Internal error: Can't initialize pens");
    }
    for (i = 0; i < NFills; i++) {
        fillBitmaps[i] = CreateBitmap(8, 8, 1, 1, fillList[i]);
    }
    SelectObject(osdc, drawPen);
    */
}

/*
 * Function: DisplayExit
 * Usage: DisplayExit();
 * ---------------------
 * This function is called when the program exits and waits for the
 * user to type a carriage return.  After reading and ignoring the
 * return key, this function frees the window system handles and
 * destroys the console window, thereby exiting the program.
 */

static void DisplayExit(void)
{
    int i;

    if (pauseOnExit) (void) getchar();
    [controllerobj close];
    [osim autorelease];
    [controllerobj autorelease];
    //DeleteDC(osdc);
    //DeleteDC(gdc);
    //DestroyWindow(consoleWindow);
    //DestroyWindow(graphicsWindow);
    //DeleteObject(drawPen);
    //DeleteObject(erasePen);
    //DeleteObject(nullPen);
    /*
    for (i = 0; i < nFonts; i++) {
        DeleteObject(fontTable[i].font);
    }
    for (i = 0; i < NFills; i++) {
        DeleteObject(fillBitmaps[i]);
    }
    */
    
}

// Console-related functions are unsupported on Mac OS X port
// Window definition is done by NSWindowController automatically thus
// no need to implement

/*
 * Function: DoUpdate
 * Usage: DoUpdate();
 * ------------------
 * This function redraws the graphics window by copying bits from
 * the offscreen bitmap behind the osdc device context into the
 * actual display context.
 */

static void DoUpdate(void)
{
   [canvasobj setNeedsDisplay:YES];
}

/*
 * Function: DisplayClear
 * Usage: DisplayClear();
 * ----------------------
 * This function clears all the bits in the offscreen bitmap.
 */

void DisplayClear(void)
{
    [osim lockFocus];
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [[NSColor whiteColor] set];
    NSRectFill(NSMakeRect(0,0,win_width,win_height));
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    [osim unlockFocus];
}

/*
 * Function: PrepareToDraw
 * Usage: PrepareToDraw();
 * -----------------------
 * This function must be called before any rendering operation
 * to ensure the pen modes and colors are correctly set.
 */

static void PrepareToDraw(void)
{
/*
    HPEN oldPen;
*/

    if (eraseMode) {
        currentColor = eraseColor;
    } else {
        if (penColor != previousColor) {
            [drawColor release];
            drawColor = [[NSColor colorWithCalibratedRed:colorTable[penColor].red
            									  green:colorTable[penColor].green
            									   blue:colorTable[penColor].blue
            									  alpha:1] retain];
            currentColor = drawColor;
            previousColor = penColor;
        }
    }
}

/*
 * Function: DisplayLine
 * Usage: DisplayLine(x, y, dx, dy);
 * ---------------------------------
 * This function renders a line into the offscreen bitmap.  If the
 * region is started, it adds the line to the developing polygonal
 * region instead.
 */

static void DisplayLine(double x, double y, double dx, double dy)
{
    int x0, y0, x1, y1;

    PrepareToDraw();
    x0 = ScaleX(x);
    y0 = ScaleY(y);
    x1 = ScaleX(x + dx);
    y1 = ScaleY(y + dy);
    if (regionState == NoRegion) {
    	NSBezierPath *line;
    	[osim lockFocus];
        line = [NSBezierPath bezierPath];
        [line moveToPoint:NSMakePoint(x0,y0)];
        [line lineToPoint:NSMakePoint(x1,y1)];
        [line setLineWidth:penSize];
        [currentColor set];
        [line stroke];
        [osim unlockFocus];
    } else {
        AddSegment(x0, y0, x1, y1);
    }
}

/*
 * Function: DisplayArc
 * Usage: DisplayArc(xc, yc, rx, ry, start, sweep);
 * ------------------------------------------------
 * This function is used to draw an arc.  The arguments are slightly
 * different from those in the client interface because xc and yc
 * designate the center.  This function is only called if a region
 * is not being assembled; if it is, the package calls RenderArc
 * instead.
 */
 
 //Used the solution from StackOverflow to deal with elliptical arc.

static void DisplayArc(double xc, double yc, double rx, double ry,
                       double start, double sweep)
{
    int xcenter, ycenter, xradius, yradius;
    double radstart, radend;
    NSBezierPath *arc, *clip;

    PrepareToDraw();
    
    if (sweep < 0) {
        start += sweep;
        sweep = -sweep;
    }
    if (start < 0) {
        start = 360 - fmod(-start, 360);
    } else {
        start = fmod(start, 360);
    }
    
    xcenter = ScaleX(xc);
    ycenter = ScaleY(yc);
    xradius = PixelsX(rx);
    yradius = PixelsY(ry);
    radstart = start;
    radend = start+sweep;
    
    [osim lockFocus];
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [currentColor set];
    clip = [NSBezierPath bezierPath];
    [clip appendBezierPathWithArcWithCenter:NSMakePoint(xcenter,ycenter) radius:Max(xradius,yradius)+penSize startAngle:radstart endAngle:radend];
    [clip lineToPoint:NSMakePoint(xcenter,ycenter)];
    [clip closePath];
    [clip addClip];
    arc = [NSBezierPath bezierPath];
    [arc appendBezierPathWithOvalInRect:NSMakeRect(xcenter-xradius,ycenter-yradius,2*xradius,2*yradius)];
    [arc setLineWidth:penSize];
    [arc stroke];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    [osim unlockFocus];
}

/*
 * Function: RenderArc
 * Usage: RenderArc(xc, yc, rx, ry, start, sweep);
 * -----------------------------------------------
 * This function is identical to DisplayArc except that, instead
 * of calling the Arc function, RenderArc simulates the arc by
 * constructing a path of consecutive segments, which are added
 * to the current polygonal region.
 */

static void RenderArc(double x, double y, double rx, double ry,
                      double start, double sweep)
{
    double t, mint, maxt, dt, maxd;
    int ix0, iy0, ix1, iy1;

    PrepareToDraw();
    if (sweep < 0) {
        start += sweep;
        sweep = -sweep;
    }
    if (fabs(rx) > fabs(ry)) {
        maxd = fabs(rx);
    } else {
        maxd = fabs(rx);
    }
    dt = atan2(InchesY(1), maxd);
    mint = Radians(start);
    maxt = Radians(start + sweep);
    ix0 = ScaleX(x + rx * cos(mint));
    iy0 = ScaleY(y + ry * sin(mint));
    for (t = mint + dt; t < maxt; t += dt) {
        if (t > maxt - dt / 2) t = maxt;
        ix1 = ScaleX(x + rx * cos(t));
        iy1 = ScaleY(y + ry * sin(t));
        AddSegment(ix0, iy0, ix1, iy1);
        ix0 = ix1;
        iy0 = iy1;
    }
}

/*
 * Function: DisplayText
 * Usage: DisplayText(x, y, text);
 * -------------------------------
 * This function displays a text string at (x, y) in the current
 * font and size.  The hard work is done in DisplayFont.
 */

static void DisplayText(double x, double y, string text)
{
	NSMutableAttributedString *txt;
    PrepareToDraw();
    txt = [[NSMutableAttributedString alloc] initWithString:[[NSString alloc] initWithCString:text]];
    [txt addAttribute:NSFontAttributeName
    			value:lgCurrentFont
    			range:NSMakeRange(0,[txt length])];
    [txt addAttribute:NSForegroundColorAttributeName
                        value:currentColor
                        range:NSMakeRange(0,[txt length])];
    [osim lockFocus];
    [[NSGraphicsContext currentContext] saveGraphicsState];
    //[currentColor set];
    [txt drawAtPoint:NSMakePoint(ScaleX(x),ScaleY(y)+[lgCurrentFont descender])];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    [osim unlockFocus];
}

/*
 * Function: DisplayFont
 * Usage: DisplayFont(font, size, style);
 * --------------------------------------
 * This function updates the font information used for drawing
 * text.  The program first uses FindExistingFont to see
 * if the desired font/size pair has been entered in the table,
 * in which case the program uses the stored handle of the font.
 * If not, the program uses CreateFont to try to create an
 * appropriate font, accepting only those whose typeface
 * matches the desired font string.  If an acceptable font
 * is found, its data is entered into the font table.
 */

static void DisplayFont(string font, int size, int style)
{
    char fontBuffer[MaxFontName + 1];
    char faceName[MaxFontName + 1];
    string fontName;
    NSFont * newFont;
    //TEXTMETRIC metrics;
    int i, fontIndex;

    for (i = 0; (fontBuffer[i] = tolower(font[i])) != '\0'; i++);
    if (StringEqual("default", fontBuffer)) {
        fontName = DefaultFont;
    } else {
        fontName = fontBuffer;
    }
    fontIndex = FindExistingFont(fontName, size, style);
    if (fontIndex == -1) {
        newFont = [NSFont fontWithName:[[NSString alloc] initWithCString:font] size:size];
        if (newFont != nil) {
                if (nFonts == MaxFonts) Error("Too many fonts loaded");
                [newFont retain];
                fontIndex = nFonts++;
                fontTable[fontIndex].name = CopyString(fontName);
                fontTable[fontIndex].size = size;
                fontTable[fontIndex].style = style;
                fontTable[fontIndex].font = newFont;
                fontTable[fontIndex].ascent = [newFont ascender];
                fontTable[fontIndex].descent = [newFont descender];
                fontTable[fontIndex].height = [newFont ascender] + [newFont descender];
                //fontTable[fontIndex].points = [newFont ascender] + [newFont descender] - [newFont leading];
                fontTable[fontIndex].points = size;
                currentFont = fontIndex;
                textFont = CopyString(font);
                lgCurrentFont = newFont;
                //pointSize = fontTable[fontIndex].points;
                pointSize = size;
                textStyle = style;
        } else {
            NSLog(@"Invalid font: %s",font);
        }
    } else {
        lgCurrentFont = fontTable[fontIndex].font;
        currentFont = fontIndex;
        textFont = CopyString(font);
        pointSize = fontTable[fontIndex].points;
        textStyle = style;
    }
}

/*
 * Function: FindExistingFont
 * Usage: fontIndex = FindExistingFont(name, size, style);
 * -------------------------------------------------------
 * This function searches the font table for a matching font
 * entry.  The function returns the matching table index or -1 if
 * no match is found, The caller has already converted the name
 * to lower case to preserve the case-insensitivity requirement.
 */

static int FindExistingFont(string name, int size, int style)
{
    int i;

    for (i = 0; i < nFonts; i++) {
        if (StringEqual(name, fontTable[i].name)
            && size == fontTable[i].size
            && style == fontTable[i].style) return (i);
    }
    return (-1);
}

/*
 * Function: SetLineBB
 * Usage: SetLineBB(&rect, x, y, dx, dy);
 * --------------------------------------
 * This function sets the rectangle dimensions to the bounding
 * box of the line.
 */

static void SetLineBB(NSRect *rp, double x, double y, double dx, double dy)
{
    int x0, y0, x1, y1;

    x0 = ScaleX(x);
    y0 = ScaleY(y);
    x1 = ScaleX(x + dx);
    y1 = ScaleY(y + dy);
    rp->origin.x = Min(x0,x1);
    rp->origin.y = Min(y0,y1);
    rp->size.width = Max(x0,x1)-rp->origin.x+1;
    rp->size.height = Max(y0,y1)-rp->origin.y+1;
}

//SetArcBB Unimplemented for no usage

/*
 * Function: SetTextBB
 * Usage: SetTextBB(&rect, x, y, text);
 * -------------------------------------
 * This function sets the rectangle dimensions to the bounding
 * box of the text string using the current font and size.
 */

static void SetTextBB(NSRect *rp, double x, double y, string text)
{
    NSSize textSize;
    NSMutableAttributedString *str;
    int ix, iy;
	
	str = [[NSMutableAttributedString alloc] initWithString:[[NSString alloc] initWithCString:text]];
    [str addAttribute:NSFontAttributeName
    			value:lgCurrentFont
    			range:NSMakeRange(0,[str length])];
   	textSize = [str size];
    ix = ScaleX(x);
    iy = ScaleY(y);
    LGSetRect(rp, ix, iy, textSize.width, textSize.height);
}

void LGSetRect(NSRect *rp, double ix, double iy, double width, double height) {
    //NSLog(@"Set NSRect @ %x to %lf,%lf size %lfx%lf",rp,ix,iy,width,height);
    rp->origin.x = ix;
    rp->origin.y = iy;
    rp->size.width = width;
    rp->size.height = height;
}
/*
 * Functions: StartPolygon, AddSegment, EndPolygon
 * Usage: StartPolygon();
 *        AddSegment(x0, y0, x1, y1);
 *        AddSegment(x1, y1, x2, y2);
 *        . . .
 *        DisplayPolygon();
 * ----------------------------------
 * These functions implement the notion of a region in the PC
 * world, where the easiest shape to fill is a polygon.  Calling
 * StartPolygon initializes the array polygonPoints so that
 * subsequent calls to AddSegment will add points to it.
 * The points in the polygon are assumed to be contiguous,
 * because the client interface checks for this property.
 * Because polygons involving arcs can be quite large, the
 * AddSegment code extends the polygonPoints list if needed
 * by doubling the size of the array.  All storage is freed
 * after calling DisplayPolygon.
 */

static void StartPolygon(void)
{
    polygonPoints = NewArray(PStartSize, NSPoint);
    polygonSize = PStartSize;
    nPolygonPoints = 0;
    //LGSetRect(&polygonBounds, LargeInt, LargeInt, 0, 0); We won't use polygonBounds.
}

static void AddSegment(int x0, int y0, int x1, int y1)
{
    if (nPolygonPoints == 0) AddPolygonPoint(x0, y0);
    AddPolygonPoint(x1, y1);
}

static void DisplayPolygon(void)
{
    float alpha; int i; float r,g,b;
    NSBezierPath *polygon;
    NSColor *fillColor;
	
    [currentColor getRed:&r green:&g blue:&b alpha:&alpha];
	
    PrepareToDraw();

    if (eraseMode) {
        alpha = 1;
    } else {
        alpha = regionDensity;
    }
    
    polygon = [NSBezierPath bezierPath];
    fillColor = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:alpha];
    
    if (nPolygonPoints == 0) return;
    [osim lockFocus];
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [polygon moveToPoint:polygonPoints[0]];
    for (i=1; i<nPolygonPoints; i++) {
    	[polygon lineToPoint:polygonPoints[i]];
    }
    [polygon closePath];
    [polygon setLineWidth:penSize];
    [currentColor set];
    [polygon stroke];
    [fillColor set];
    [polygon fill];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    [osim unlockFocus];
    //[fillColor autorelease];
}

static void AddPolygonPoint(int x, int y)
{
    NSPoint *newPolygon;
    int i;

    if (nPolygonPoints >= polygonSize) {
        polygonSize *= 2;
        newPolygon = NewArray(polygonSize, NSPoint);
        for (i = 0; i < nPolygonPoints; i++) {
            newPolygon[i] = polygonPoints[i];
        }
        FreeBlock(polygonPoints);
        polygonPoints = newPolygon;
    }
    //polygonBounds.left = Min(polygonBounds.left, x);
    //polygonBounds.right = Max(polygonBounds.right, x);
    //polygonBounds.top = Min(polygonBounds.top, y);
    //polygonBounds.bottom = Max(polygonBounds.bottom, y);
    polygonPoints[nPolygonPoints].x = x;
    polygonPoints[nPolygonPoints].y = y;
    nPolygonPoints++;
}

/*
 * Function: InitColors
 * Usage: InitColors();
 * --------------------
 * This function defines the built-in colors.
 */

static void InitColors(void)
{
    nColors = 0;
    DefineColor("Black", 0, 0, 0);
    DefineColor("Dark Gray", .35, .35, .35);
    DefineColor("Gray", .6, .6, .6);
    DefineColor("Light Gray", .75, .75, .75);
    DefineColor("White", 1, 1, 1);
    DefineColor("Brown", .35, .20, .05);
    DefineColor("Red", 1, 0, 0);
    DefineColor("Orange", 1, .40, .1);
    DefineColor("Yellow", 1, 1, 0);
    DefineColor("Green", 0, 1, 0);
    DefineColor("Blue", 0, 0, 1);
    DefineColor("Violet", .93, .5, .93);
    DefineColor("Magenta", 1, 0, 1);
    DefineColor("Cyan", 0, 1, 1);
}

/*
 * Function: FindColorName
 * Usage: index = FindColorName(name);
 * -----------------------------------
 * This function returns the index of the named color in the
 * color table, or -1 if the color does not exist.
 */

static int FindColorName(string name)
{
    int i;

    for (i = 0; i < nColors; i++) {
        if (StringMatch(name, colorTable[i].name)) return (i);
    }
    return (-1);
}

/*
 * Utility functions
 * -----------------
 * This section contains several extremely short utility functions
 * that improve the readability of the code.
 */

/*
 * Function: StringMatch
 * Usage: if (StringMatch(s1, s2)) . . .
 * -------------------------------------
 * This function returns TRUE if two strings are equal, ignoring
 * case distinctions.
 */

static BOOL StringMatch(string s1, string s2)
{
    register char *cp1, *cp2;

    cp1 = s1;
    cp2 = s2;
    while (tolower(*cp1) == tolower(*cp2)) {
        if (*cp1 == '\0') return (YES);
        cp1++;
        cp2++;
    }
    return (NO);
}

/*
 * Function: PrefixMatch
 * Usage: if (PrefixMatch(prefix, str)) . . .
 * -------------------------------------------------
 * This function returns TRUE if prefix is the initial substring
 * of str, ignoring differences in case.
 */

static BOOL PrefixMatch(char *prefix, char *str)
{
    while (*prefix != '\0') {
        if (tolower(*prefix++) != tolower(*str++)) return (NO);
    }
    return (YES);
}

/*
 * Functions: RectWidth, RectHeight
 * Usage: w = RectWidth(&r);
 *        h = RectHeight(&r);
 * --------------------------------
 * These functions return the width and height of a rectangle.
 */

static int RectWidth(NSRect *rp)
{
    return (rp->size.width);
}

static int RectHeight(NSRect *rp)
{
    return (rp->size.height);
}

//LGSetRect and LGSetRectFromSize works the same right now.
/*
 * Functions: LGSetRectFromSize
 * Usage: LGSetRectFromSize(&r, x, y, width, height);
 * ------------------------------------------------
 * This function is similar to LGSetRect except that it takes width
 * and height parameters rather than right and bottom.
 */

static void LGSetRectFromSize(NSRect *rp, int x, int y, int width, int height)
{
    LGSetRect(rp, x, y, width, height);
}

/*
 * Function: Radians
 * Usage: radians = Radians(degrees);
 * ----------------------------------
 * This functions convert an angle in degrees to radians.
 */

static double Radians(double degrees)
{
    return (degrees * Pi / 180);
}

/*
 * Function: Round
 * Usage: n = Round(x);
 * --------------------
 * This function rounds a double to the nearest integer.
 */

static int Round(double x)
{
    return ((int) floor(x + 0.5));
}

/*
 * Functions: InchesX, InchesY
 * Usage: inches = InchesX(pixels);
 *        inches = InchesY(pixels);
 * --------------------------------
 * These functions convert distances measured in pixels to inches.
 * Because the resolution may not be uniform in the horizontal and
 * vertical directions, the coordinates are treated separately.
 */

static double InchesX(int x)
{
    return ((double) x / xResolution);
}

static double InchesY(int y)
{
    return ((double) y / yResolution);
}

/*
 * Functions: PixelsX, PixelsY
 * Usage: pixels = PixelsX(inches);
 *        pixels = PixelsY(inches);
 * --------------------------------
 * These functions convert distances measured in inches to pixels.
 */

static int PixelsX(double x)
{
    return (Round(x * xResolution + Epsilon));
}

static int PixelsY(double y)
{
    return (Round(y * yResolution + Epsilon));
}

/*
 * Functions: ScaleX, ScaleY
 * Usage: pixels = ScaleX(inches);
 *        pixels = ScaleY(inches);
 * --------------------------------
 * These functions are like PixelsX and PixelsY but convert coordinates
 * rather than lengths.  The difference is that y-coordinate values must
 * be inverted top to bottom to support the cartesian coordinates of
 * the graphics.h model.
 */

static int ScaleX(double x)
{
    return (PixelsX(x));
}

static int ScaleY(double y)
{
    return (PixelsY(y));
}

/*
 * Functions: Min, Max
 * Usage: min = Min(x, y);
 *        max = Max(x, y);
 * -----------------------
 * These functions find the minimum and maximum of two integers.
 */

static int Min(int x, int y)
{
    return ((x < y) ? x : y);
}

static int Max(int x, int y)
{
    return ((x > y) ? x : y);
}

void registerKeyboardEvent(KeyboardEventCallback callback)
{
	g_keyboard = callback;
}

void registerCharEvent(CharEventCallback callback)
{
	g_char = callback;
}

void registerMouseEvent(MouseEventCallback callback)
{
	g_mouse = callback;
}

void registerTimerEvent(TimerEventCallback callback)
{
	g_timer = callback;
}

void cancelKeyboardEvent()
{
    g_keyboard = NULL;
}

void cancelCharEvent()
{
    g_char = NULL;
}

void cancelMouseEvent()
{
    g_mouse = NULL;
}

void cancelTimerEvent()
{
    g_timer = NULL;
}

void startTimer(int timerID,int timeinterval)
{
	[appctrlobj recordAndScheduleTimer:timerID interval:(double)timeinterval/1000];
}

void cancelTimer(int timerID)
{
	[appctrlobj invalideTimerById:timerID];
}

void SGEnableMouseMoveCapture() {
    [windowobj setAcceptsMouseMovedEvents:YES];
}

void SGDisableMouseMoveCapture() {
    [windowobj setAcceptsMouseMovedEvents:NO];
}

double ScaleXInches(int x) {
    return (double)x/GetXResolution();
}

double ScaleYInches(int y)
{
    return (double)y/GetYResolution();
}
//WIP: IMPLEMENT GraphicsEventProc / CheckEvents

@implementation SimpleGraphics

- (void) actTimerFired:(int) timerID {
	if (g_timer) {g_timer(timerID); [theCanvas setNeedsDisplay:YES];}
}

- (void) initVars {
    canvasobj = theCanvas;
    windowobj = theWindow;
    controllerobj = theController;
    appctrlobj = appController;
    selfobj = self;
}

- (void) actKeydown:(NSEvent *)evt {
    NSString *chrs = [evt characters];
    unsigned short code;
    if (g_keyboard) {g_keyboard(MAConvertMacVkeyToWin([evt keyCode]),KEY_DOWN); [theCanvas setNeedsDisplay:YES];}
    if ([chrs length]==1)
    {
        code = [chrs characterAtIndex:0];
        if (code >=0x20 && code <=0x7F)
            if (g_char) {g_char(code);[theCanvas setNeedsDisplay:YES];} // Stub. NSTextInput to be implemented.
    }
}

- (void) actKeyup:(NSEvent *)evt {
    if (g_keyboard) {g_keyboard(MAConvertMacVkeyToWin([evt keyCode]),KEY_UP);[theCanvas setNeedsDisplay:YES];}
}

- (void) actModifierKey:(int)key down:(BOOL)isDown {
    if (g_keyboard) {g_keyboard(MAConvertMacVkeyToWin(key),isDown?KEY_DOWN:KEY_UP);[theCanvas setNeedsDisplay:YES];}
}

- (void) actMousedown {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    mouseButton = YES;
    g_mouse(rpt.x,rpt.y,LEFT_BUTTON,BUTTON_DOWN);
    [theCanvas setNeedsDisplay:YES];
}

- (void) actMouseup {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    mouseButton = NO;
    g_mouse(rpt.x,rpt.y,LEFT_BUTTON,BUTTON_UP);
    [theCanvas setNeedsDisplay:YES];
}

- (void) actRightmousedown {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    mouseButton = YES;
    g_mouse(rpt.x,rpt.y,RIGHT_BUTTON,BUTTON_DOWN);
    [theCanvas setNeedsDisplay:YES];
}

- (void) actRightmouseup {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    g_mouse(rpt.x,rpt.y,RIGHT_BUTTON,BUTTON_UP);
    mouseButton = NO;
    [theCanvas setNeedsDisplay:YES];
}

- (void) actMiddlemousedown {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    mouseButton = YES;
    g_mouse(rpt.x,rpt.y,MIDDLE_BUTTON,BUTTON_DOWN);
    [theCanvas setNeedsDisplay:YES];
}

- (void) actMiddlemouseup {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    mouseButton = NO;
    g_mouse(rpt.x,rpt.y,MIDDLE_BUTTON,BUTTON_UP);
    [theCanvas setNeedsDisplay:YES];
}

- (void) actMousemove {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    g_mouse(rpt.x,rpt.y,MOUSEMOVE,MOUSEMOVE);
    [theCanvas setNeedsDisplay:YES];
}

- (void) actScroll:(BOOL) up {
    NSPoint pt, rpt;
    if (!g_mouse) return;
    pt = [NSEvent mouseLocation];
    rpt = [theWindow convertScreenToBase:pt];
    g_mouse(rpt.x,rpt.y,MIDDLE_BUTTON,up?ROLL_UP:ROLL_DOWN);
    [theCanvas setNeedsDisplay:YES];
}
@end
