
#ifndef ____ui_button_h______
#define ____ui_button_h______


//===========================================================================
//
//   [L:16-1][N:16-1]
//        XOR
//   [F:32 --------1]
// 
// Generate a *fake* unique ID for gui controls at compiling/run time
//
#define GenUIID(N) ( ((__LINE__<<16) | ( N & 0xFFFF))^((long)&__FILE__) )
//
// GenUIID(0) will give a unique ID at each source code line. 
// If you need one UI ID per line, just call GenUIID with 0
//
//               GenUIID(0)
//
// But, two GenUIID(0) calls at the same line will give the same ID.
//
// So, in a while/for loop body, GenUIID(0) will give you the same ID.
// In this case, you need call GenUIID with different N parameter: 
//
//               GenUIID(N)
//
//===========================================================================

void InitGUI();

void uiGetMouse(int x, int y, int button, int event);
void uiGetKeyboard(int key, int event);
void uiGetChar(int ch);



int button(int id, double x, double y, double w, double h, char *label);

int  menuList(int id, double x, double y, double w, double wlist, double h, char *labels[], int n);

void drawMenuBar(double x, double y, double w, double h); 

int textbox(int id, double x, double y, double w, double h, char textbuf[], int buflen);

void setButtonColors (char *frame, char*label, char *hotFrame, char *hotLabel, int fillflag);
void setMenuColors   (char *frame, char*label, char *hotFrame, char *hotLabel, int fillflag);
void setTextBoxColors(char *frame, char*label, char *hotFrame, char *hotLabel, int fillflag);

void usePredefinedColors(int k);
void usePredefinedButtonColors(int k);
void usePredefinedMenuColors(int k);
void usePredefinedTexBoxColors(int k);


void drawLabel(double x, double y, char *label);

void drawRectangle(double x, double y, double w, double h, int fillflag);

void drawBox(double x, double y, double w, double h, int fillflag, char *label, char xalignment, char *labelColor);

#endif // define ____ui_button_h______
