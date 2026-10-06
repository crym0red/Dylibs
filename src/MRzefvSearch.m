// MRzefvSearch.m
// Header rework: search bar -> magnifier icon, branded title + "Powered by" on the left.
// Plain ObjC, no substrate. Build: see .github/workflows/build.yml

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ---------- CONFIG ----------
#define MR_HEADER_CLASS  @"KAAppearanceView"
#define MR_TITLE         @"Free Streaming¹"
#define MR_SUBTITLE      @"Powered by DELvEK.NET"
#define MR_KEYWORDS      (@[@"search", @"搜索", @"搜尋"])
#define MR_ICON_SIZE     22.0
// ----------------------------

static const void *kBarKey   = &kBarKey;
static const void *kTitleKey = &kTitleKey;
static const void *kIconKey  = &kIconKey;
static const void *kPendKey  = &kPendKey;
static const NSInteger kOverlayTag = 0x4D52;

#pragma mark - Finding the search bar

static BOOL MRTextMatches(NSString *s) {
    if (![s isKindOfClass:NSString.class] || s.length == 0 || s.length > 30) return NO;
    NSString *l = s.lowercaseString;
    for (NSString *kw in MR_KEYWORDS) if ([l containsString:kw]) return YES;
    return NO;
}

static BOOL MRViewHasSearchText(UIView *v) {
    if ([v isKindOfClass:UILabel.class]) return MRTextMatches(((UILabel *)v).text);
    if ([v isKindOfClass:UITextField.class]) {
        UITextField *t = (UITextField *)v;
        return MRTextMatches(t.placeholder) || MRTextMatches(t.attributedPlaceholder.string) || MRTextMatches(t.text);
    }
    if ([v isKindOfClass:UIButton.class]) return MRTextMatches([(UIButton *)v titleForState:UIControlStateNormal]);
    return NO;
}

static UIView *MRFindTextNode(UIView *root) {
    if (root.tag == kOverlayTag) return nil;
    if (MRViewHasSearchText(root)) return root;
    for (UIView *s in root.subviews) {
        UIView *r = MRFindTextNode(s);
        if (r) return r;
    }
    return nil;
}

static BOOL MRHasImageView(UIView *v) {
    if ([v isKindOfClass:UIImageView.class]) return YES;
    for (UIView *s in v.subviews) if (MRHasImageView(s)) return YES;
    return NO;
}

static UIView *MRFindByGeometry(UIView *root) {
    if (root.tag == kOverlayTag) return nil;
    CGSize s = root.bounds.size;
    if (s.height >= 28 && s.height <= 44 && s.width >= 200 && s.width <= 330 && MRHasImageView(root)) return root;
    for (UIView *c in root.subviews) {
        UIView *r = MRFindByGeometry(c);
        if (r) return r;
    }
    return nil;
}

static UIView *MRBarFromNode(UIView *node, UIView *root) {
    UIView *best = nil, *v = node;
    CGFloat maxW = root.bounds.size.width - 30;
    while (v) {
        CGSize s = v.bounds.size;
        if (s.height > 56 || s.width > maxW) break;
        if (s.height >= 26 && s.width >= 120) best = v;
        if (v == root) break;
        v = v.superview;
    }
    return best;
}

static UIView *MRLocateBar(UIView *header) {
    UIView *root = header;
    for (int i = 0; i < 3 && root; i++) {
        if (root.bounds.size.height < 260 && ![root isKindOfClass:UIWindow.class]) {
            UIView *node = MRFindTextNode(root);
            if (node) {
                UIView *bar = MRBarFromNode(node, root);
                if (bar) return bar;
            }
            UIView *geo = MRFindByGeometry(root);
            if (geo) return geo;
        }
        root = root.superview;
    }
    return nil;
}

#pragma mark - Forwarding taps to the original bar

static void MRCollect(UIView *v, NSMutableArray *controls, NSMutableArray *gestures) {
    if ([v isKindOfClass:UIControl.class]) [controls addObject:v];
    for (UIGestureRecognizer *g in v.gestureRecognizers)
        if ([g isKindOfClass:UITapGestureRecognizer.class]) [gestures addObject:g];
    for (UIView *s in v.subviews) MRCollect(s, controls, gestures);
}

static BOOL MRFireGesture(UIGestureRecognizer *g) {
    NSArray *targets = nil;
    @try { targets = [g valueForKey:@"_targets"]; } @catch (__unused id e) {}
    BOOL fired = NO;
    @try { [g setValue:@(UIGestureRecognizerStateEnded) forKey:@"state"]; } @catch (__unused id e) {}
    for (id t in targets) {
        id target = nil;
        @try { target = [t valueForKey:@"target"]; } @catch (__unused id e) {}
        Ivar iv = class_getInstanceVariable(object_getClass(t), "_action");
        if (!target || !iv) continue;
        SEL a = *(SEL *)((uint8_t *)(__bridge void *)t + ivar_getOffset(iv));
        if (!a || ![target respondsToSelector:a]) continue;
        ((void (*)(id, SEL, id))objc_msgSend)(target, a, g);
        fired = YES;
    }
    return fired;
}

static BOOL MRTriggerBar(UIView *bar) {
    NSMutableArray *controls = [NSMutableArray array], *gestures = [NSMutableArray array];
    MRCollect(bar, controls, gestures);
    if (controls.count) {
        [(UIControl *)controls.firstObject sendActionsForControlEvents:UIControlEventTouchUpInside];
        return YES;
    }
    for (UIGestureRecognizer *g in gestures) if (MRFireGesture(g)) return YES;
    return NO;
}

#pragma mark - Overlay views

@interface MRProxy : NSObject
+ (void)tap:(UIControl *)sender;
@end
@implementation MRProxy
+ (void)tap:(UIControl *)sender {
    UIView *bar = objc_getAssociatedObject(sender, kBarKey);
    if (bar) MRTriggerBar(bar);
}
@end

static UIView *MRMakeTitle(void) {
    UIView *c = [[UIView alloc] init];
    c.tag = kOverlayTag;
    c.userInteractionEnabled = NO;
    UILabel *t = [[UILabel alloc] init];
    t.tag = 1;
    t.text = MR_TITLE;
    t.textColor = UIColor.whiteColor;
    t.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    t.adjustsFontSizeToFitWidth = YES;
    t.minimumScaleFactor = 0.6;
    UILabel *s = [[UILabel alloc] init];
    s.tag = 2;
    s.text = MR_SUBTITLE;
    s.textColor = [UIColor colorWithWhite:1 alpha:0.78];
    s.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    s.adjustsFontSizeToFitWidth = YES;
    s.minimumScaleFactor = 0.6;
    [c addSubview:t];
    [c addSubview:s];
    return c;
}

static UIButton *MRMakeIcon(void) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.tag = kOverlayTag;
    CGFloat box = MR_ICON_SIZE, pad = (40 - box) / 2;
    UIView *frame = [[UIView alloc] initWithFrame:CGRectMake(pad, pad, box, box)];
    frame.userInteractionEnabled = NO;
    frame.layer.borderColor = UIColor.whiteColor.CGColor;
    frame.layer.borderWidth = 1.5;
    frame.layer.cornerRadius = 6;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    UIImageView *g = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]];
    g.tintColor = UIColor.whiteColor;
    g.contentMode = UIViewContentModeCenter;
    g.frame = frame.bounds;
    g.userInteractionEnabled = NO;
    [frame addSubview:g];
    [b addSubview:frame];
    [b addTarget:MRProxy.class action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void MRSetFrame(UIView *v, CGRect r) {
    if (!CGRectEqualToRect(v.frame, r)) v.frame = r;
}

#pragma mark - Apply

static void MRApply(UIView *header) {
    if (!header.window) return;

    UIView *bar = objc_getAssociatedObject(header, kBarKey);
    if (!bar || !bar.superview || !bar.window) {
        [(UIView *)objc_getAssociatedObject(header, kTitleKey) removeFromSuperview];
        [(UIView *)objc_getAssociatedObject(header, kIconKey) removeFromSuperview];
        objc_setAssociatedObject(header, kTitleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(header, kIconKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        bar = MRLocateBar(header);
        objc_setAssociatedObject(header, kBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!bar || !bar.superview) return;

    UIView *host = bar.superview;
    UIView *title = objc_getAssociatedObject(header, kTitleKey);
    UIButton *icon = objc_getAssociatedObject(header, kIconKey);
    if (!title || title.superview != host) {
        [title removeFromSuperview];
        title = MRMakeTitle();
        [host addSubview:title];
        objc_setAssociatedObject(header, kTitleKey, title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!icon || icon.superview != host) {
        [icon removeFromSuperview];
        icon = MRMakeIcon();
        [host addSubview:icon];
        objc_setAssociatedObject(header, kIconKey, icon, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(icon, kBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGRect f = bar.frame;
    CGFloat boxX = CGRectGetMaxX(f) - MR_ICON_SIZE;
    CGFloat midY = CGRectGetMidY(f);
    MRSetFrame(icon, CGRectMake(boxX - (40 - MR_ICON_SIZE) / 2, midY - 20, 40, 40));

    CGFloat tx = f.origin.x + 4;
    CGFloat tw = MAX(40, boxX - 10 - tx);
    MRSetFrame(title, CGRectMake(tx, midY - 17, tw, 34));
    MRSetFrame([title viewWithTag:1], CGRectMake(0, 0, tw, 21));
    MRSetFrame([title viewWithTag:2], CGRectMake(0, 21, tw, 13));

    [host bringSubviewToFront:title];
    [host bringSubviewToFront:icon];

    BOOL forward = NO;
    {
        NSMutableArray *c = [NSMutableArray array], *g = [NSMutableArray array];
        MRCollect(bar, c, g);
        forward = (c.count + g.count) > 0;
    }
    if (forward) {
        bar.alpha = 0;
        bar.userInteractionEnabled = NO;
        icon.userInteractionEnabled = YES;
    } else {
        // nothing to forward to: keep bar invisible but live underneath, touches fall through
        bar.alpha = 0.011;
        bar.userInteractionEnabled = YES;
        icon.userInteractionEnabled = NO;
    }
}

#pragma mark - Hook

static void (*orig_layout)(id, SEL);
static void hook_layout(UIView *self, SEL _cmd) {
    orig_layout(self, _cmd);
    MRApply(self);
    if (!objc_getAssociatedObject(self, kPendKey)) {
        objc_setAssociatedObject(self, kPendKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIView *w = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *s = w;
            if (!s) return;
            objc_setAssociatedObject(s, kPendKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            MRApply(s);
        });
    }
}

static void MRInstall(int attempt) {
    Class c = NSClassFromString(MR_HEADER_CLASS);
    if (!c) {
        if (attempt < 40)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ MRInstall(attempt + 1); });
        return;
    }
    SEL sel = @selector(layoutSubviews);
    Method m = class_getInstanceMethod(c, sel);
    if (!m) return;
    IMP o = method_getImplementation(m);
    if (!class_addMethod(c, sel, (IMP)hook_layout, method_getTypeEncoding(m)))
        method_setImplementation(m, (IMP)hook_layout);
    orig_layout = (void (*)(id, SEL))o;
}

#pragma mark - Splash (black + remote logo)

#define MR_SPLASH_URL  @"https://delvek.net/img/ZEFvEK.png"
#define MR_SPLASH_MIN  1.5   // seconds, minimum on screen once image is ready
#define MR_SPLASH_MAX  4.0   // seconds, hard cap

static UIWindow *gSplashWin;
static UIImageView *gSplashIV;
static CFTimeInterval gSplashStart;
static BOOL gSplashDone, gSplashImgReady;

static NSString *MRSplashCachePath(void) {
    NSString *d = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    return [d stringByAppendingPathComponent:@"mrzefv_splash.png"];
}

static void MRSplashSetImage(UIImage *img) {
    if (!img || !gSplashIV) return;
    gSplashIV.image = img;
    gSplashImgReady = YES;
}

static void MRSplashDismiss(void) {
    if (gSplashDone) return;
    gSplashDone = YES;
    UIWindow *w = gSplashWin;
    [UIView animateWithDuration:0.35 animations:^{ w.alpha = 0; } completion:^(BOOL f) {
        w.hidden = YES;
        gSplashWin = nil;
        gSplashIV = nil;
    }];
}

static void MRSplashWatch(void) {
    if (gSplashDone || !gSplashWin) return;
    CFTimeInterval el = CACurrentMediaTime() - gSplashStart;
    if (el >= MR_SPLASH_MAX || (gSplashImgReady && el >= MR_SPLASH_MIN)) { MRSplashDismiss(); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ MRSplashWatch(); });
}

static void MRSplashShow(UIWindowScene *scene) {
    UIWindow *w = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                        : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    w.windowLevel = UIWindowLevelAlert + 1000;
    w.backgroundColor = UIColor.blackColor;
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.blackColor;
    w.rootViewController = vc;

    UIImageView *iv = [[UIImageView alloc] init];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:iv];
    [NSLayoutConstraint activateConstraints:@[
        [iv.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [iv.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
        [iv.widthAnchor constraintEqualToAnchor:vc.view.widthAnchor multiplier:0.7],
        [iv.heightAnchor constraintEqualToAnchor:iv.widthAnchor],
    ]];

    gSplashWin = w;
    gSplashIV = iv;
    gSplashStart = CACurrentMediaTime();
    NSData *cd = [NSData dataWithContentsOfFile:MRSplashCachePath()];
    if (cd) MRSplashSetImage([UIImage imageWithData:cd]);
    w.hidden = NO;
    MRSplashWatch();
}

static void MRSplashPoll(int n) {
    if (gSplashWin || gSplashDone) return;
    UIWindowScene *sc = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:UIWindowScene.class]) { sc = (UIWindowScene *)s; break; }
    if (sc || n > 50) { MRSplashShow(sc); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ MRSplashPoll(n + 1); });
}

static void MRSplashFetch(void) {
    NSURL *u = [NSURL URLWithString:MR_SPLASH_URL];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6];
    [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e) {
        UIImage *img = (d.length && !e) ? [UIImage imageWithData:d] : nil;
        if (!img) return;
        [d writeToFile:MRSplashCachePath() atomically:YES];
        dispatch_async(dispatch_get_main_queue(), ^{ MRSplashSetImage(img); });
    }] resume];
}

__attribute__((constructor))
static void MRInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        MRSplashPoll(0);
        MRSplashFetch();
        MRInstall(0);
    });
}
