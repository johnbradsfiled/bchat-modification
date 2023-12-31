//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import "UIColor+OWS.h"
#import "OWSMath.h"
#import <SignalCoreKit/Cryptography.h>

NS_ASSUME_NONNULL_BEGIN

@implementation UIColor (OWS)

#pragma mark -

+ (UIColor *)ows_signalBrandBlueColor
{
    return UIColor.beldexGreen;
}

+ (UIColor *)ows_materialBlueColor
{
    return UIColor.beldexGreen;
}

+ (UIColor *)ows_darkIconColor
{
    return UIColor.beldexGreen;
}

+ (UIColor *)ows_darkGrayColor
{
    return UIColor.beldexDarkGray;
}

+ (UIColor *)ows_darkThemeBackgroundColor
{
    return UIColor.beldexDarkestGray;
}

+ (UIColor *)ows_fadedBlueColor
{
    // blue: #B6DEF4
    return [UIColor colorWithRed:182.f / 255.f green:222.f / 255.f blue:244.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_yellowColor
{
    // gold: #FFBB5C
    return [UIColor colorWithRed:245.f / 255.f green:186.f / 255.f blue:98.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_reminderYellowColor
{
    return [UIColor colorWithRed:252.f / 255.f green:240.f / 255.f blue:217.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_reminderDarkYellowColor
{
    return [UIColor colorWithRGBHex:0xFCDA91];
}

+ (UIColor *)ows_destructiveRedColor
{
    return [UIColor colorWithRGBHex:0xF44336];
}

+ (UIColor *)ows_errorMessageBorderColor
{
    return [UIColor colorWithRed:195.f / 255.f green:0 blue:22.f / 255.f alpha:1.0f];
}

+ (UIColor *)ows_infoMessageBorderColor
{
    return [UIColor colorWithRed:239.f / 255.f green:189.f / 255.f blue:88.f / 255.f alpha:1.0f];
}

+ (UIColor *)ows_lightBackgroundColor
{
    return [UIColor colorWithRed:242.f / 255.f green:242.f / 255.f blue:242.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_systemPrimaryButtonColor
{
    return UIColor.beldexGreen;
}

+ (UIColor *)ows_messageBubbleLightGrayColor
{
    return [UIColor colorWithHue:240.0f / 360.0f saturation:0.02f brightness:0.92f alpha:1.0f];
}

+ (UIColor *)colorWithRGBHex:(unsigned long)value
{
    CGFloat red = ((value >> 16) & 0xff) / 255.f;
    CGFloat green = ((value >> 8) & 0xff) / 255.f;
    CGFloat blue = ((value >> 0) & 0xff) / 255.f;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.f];
}

- (UIColor *)blendWithColor:(UIColor *)otherColor alpha:(CGFloat)alpha
{
    CGFloat r0, g0, b0, a0;
#ifdef DEBUG
    BOOL result =
#endif
        [self getRed:&r0 green:&g0 blue:&b0 alpha:&a0];
    OWSAssertDebug(result);

    CGFloat r1, g1, b1, a1;
#ifdef DEBUG
    result =
#endif
        [otherColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    OWSAssertDebug(result);

    alpha = CGFloatClamp01(alpha);
    return [UIColor colorWithRed:CGFloatLerp(r0, r1, alpha)
                           green:CGFloatLerp(g0, g1, alpha)
                            blue:CGFloatLerp(b0, b1, alpha)
                           alpha:CGFloatLerp(a0, a1, alpha)];
}

#pragma mark - Color Palette

+ (UIColor *)ows_signalBlueColor
{
    return [UIColor colorWithRGBHex:0x2090EA];
}

+ (UIColor *)ows_greenColor
{
    return [UIColor colorWithRGBHex:0x4caf50];
}

+ (UIColor *)ows_redColor
{
    return [UIColor colorWithRGBHex:0xf44336];
}

#pragma mark - GreyScale

+ (UIColor *)ows_whiteColor
{
    return [UIColor colorWithRGBHex:0xFFFFFF];
}

+ (UIColor *)ows_gray02Color
{
    return [UIColor colorWithRGBHex:0xF8F9F9];
}

+ (UIColor *)ows_gray05Color
{
    return [UIColor colorWithRGBHex:0xEEEFEF];
}

+ (UIColor *)ows_gray25Color
{
    return [UIColor colorWithRGBHex:0xBBBDBE];
}

+ (UIColor *)ows_gray45Color
{
    return [UIColor colorWithRGBHex:0x898A8C];
}

+ (UIColor *)ows_gray60Color
{
    return [UIColor colorWithRGBHex:0x636467];
}

+ (UIColor *)ows_gray75Color
{
    return [UIColor colorWithRGBHex:0x3D3E44];
}

+ (UIColor *)ows_gray90Color
{
    return [UIColor colorWithRGBHex:0x17191D];
}

+ (UIColor *)ows_gray95Color
{
    return [UIColor colorWithRGBHex:0x0F1012];
}

+ (UIColor *)ows_blackColor
{
    return [UIColor colorWithRGBHex:0x000000];
}

// TODO: Remove
+ (UIColor *)ows_darkSkyBlueColor
{
    // HEX 0xc2090EA
    return [UIColor colorWithRed:32.f / 255.f green:144.f / 255.f blue:234.f / 255.f alpha:1.f];
}

#pragma mark - Beldex

+ (UIColor *)beldexGreen { return [UIColor colorWithRGBHex:0x78BE20]; }
+ (UIColor *)beldexDarkGreen { return [UIColor colorWithRGBHex:0x419B41]; }
+ (UIColor *)beldexDarkestGray { return [UIColor colorWithRGBHex:0x0A0A0A]; }
+ (UIColor *)beldexDarkerGray { return [UIColor colorWithRGBHex:0x252525]; }
+ (UIColor *)beldexDarkGray { return [UIColor colorWithRGBHex:0x313131]; }
+ (UIColor *)beldexGray { return [UIColor colorWithRGBHex:0x363636]; }
+ (UIColor *)beldexLightGray { return [UIColor colorWithRGBHex:0x414141]; }
+ (UIColor *)beldexLightestGray { return [UIColor colorWithRGBHex:0x818181]; }

@end

NS_ASSUME_NONNULL_END
