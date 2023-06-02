#import "GraphicView.h"
#import "SimpleGraphics.h"
extern NSImage *osim;
extern int win_width, win_height;
@implementation GraphicView

- (BOOL) acceptsFirstResponder {
    return YES;
}

- (void) mouseDown:(NSEvent *)aEvent {
    [libGraphics actMousedown];
}

- (void) mouseUp:(NSEvent *)aEvent {
    [libGraphics actMouseup];
}

- (void) rightMouseDown:(NSEvent *)aEvent {
    [libGraphics actRightmousedown];
}

- (void) rightMouseUp:(NSEvent *)aEvent {
    [libGraphics actRightmouseup];
}

- (void) otherMouseDown:(NSEvent *)aEvent {
    [libGraphics actMiddlemousedown];
}

- (void) otherMouseUp:(NSEvent *)aEvent {
    [libGraphics actMiddlemouseup];
}

- (void) scrollWheel:(NSEvent *)evt {
    [libGraphics actScroll:([evt scrollingDeltaY]>0)];
}

- (void) keyDown:(NSEvent *)aEvent {
    [libGraphics actKeydown:aEvent];
}

- (void) keyUp:(NSEvent *)aEvent {
    [libGraphics actKeyup:aEvent];
}

- (void) flagsChanged:(NSEvent *)aEvent {
    int code = [aEvent keyCode];
    int mod = [aEvent modifierFlags];
    switch (code) {
        case 0x39: //CAPS
            [libGraphics actModifierKey:code down:((mod&NSAlphaShiftKeyMask)!=0)];
            break;
        case 0x38: //SHIFT
            [libGraphics actModifierKey:code down:((mod&NSShiftKeyMask)!=0)];
            break;
        case 0x3B: //CTRL
            [libGraphics actModifierKey:code down:((mod&NSControlKeyMask)!=0)];
            break;
        case 0x3A: //OPTN
            [libGraphics actModifierKey:code down:((mod&NSAlternateKeyMask)!=0)];
            break;
        case 0x37: //CMD
            [libGraphics actModifierKey:code down:((mod&NSCommandKeyMask)!=0)];
            break;
        case 0x72: //INS
            [libGraphics actModifierKey:code down:((mod&NSHelpKeyMask)!=0)];
            break;
        default:
            NSLog(@"Unsupported modifier keycode=%d",code);
    }
    //NSLog(@"Modifier KeyDown VK %d",[aEvent keyCode]);
}

- (void) mouseMoved: (NSEvent *)evt {
    [libGraphics actMousemove];
}

- (void) mouseDragged: (NSEvent *)evt {
    [libGraphics actMousemove];
}


- (void) drawRect:(NSRect)rect {
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [osim drawAtPoint:NSMakePoint(0,0) fromRect:NSMakeRect(0,0,win_width,win_height)
    operation:NSCompositeCopy fraction:1.0];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
