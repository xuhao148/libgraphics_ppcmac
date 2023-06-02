/* GraphicView */

#import <Cocoa/Cocoa.h>

@interface GraphicView : NSView
{
    IBOutlet id libGraphics;
}
- (void) drawRect:(NSRect)rect;
@end
