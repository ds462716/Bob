//
//  ViewController.m
//  ifanyi
//
//  Created by ripper on 2019/10/19.
//  Copyright © 2019 ripperhe. All rights reserved.
//

#import "TranslateViewController.h"
#import "BaiduTranslate.h"
#import "Selection.h"
#import "PopUpButton.h"
#import "QueryView.h"
#import "ResultView.h"
#import "Configuration.h"
#import <AVFoundation/AVFoundation.h>
#import "ImageButton.h"

@interface TranslateViewController ()

@property (nonatomic, strong) BaiduTranslate *baiduTranslate;
@property (nonatomic, strong) NSArray<NSNumber *> *languages;
@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, strong) NSButton *pinButton;
@property (nonatomic, strong) NSButton *foldButton;
@property (nonatomic, strong) QueryView *queryView;
@property (nonatomic, strong) PopUpButton *fromLanguageButton;
@property (nonatomic, strong) ImageButton *transformButton;
@property (nonatomic, strong) PopUpButton *toLanguageButton;
@property (nonatomic, strong) ResultView *resultView;

@end

@implementation TranslateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupTranslate];
    [self setupViews];
}

- (void)setupViews {
    // 可整体拖拽，后期修改
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.view.window.movableByWindowBackground = YES;
    });
    
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = NSColor.whiteColor.CGColor;
    
    self.pinButton = [NSButton mm_make:^(NSButton * button) {
        [self.view addSubview:button];
        button.bordered = NO;
        button.imageScaling = NSImageScaleProportionallyDown;
        button.bezelStyle = NSBezelStyleRegularSquare;
        [button setButtonType:NSButtonTypeToggle];
        button.image = [NSImage imageNamed:@"pin_normal"];
        button.alternateImage = [NSImage imageNamed:@"pin_selected"];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.offset(6);
            make.width.height.mas_equalTo(32);
        }];
        mm_weakify(button)
        [button setRac_command:[[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(id  _Nullable input) {
            mm_strongify(button)
            NSLog(@"点击按钮 %@", button.state == NSControlStateValueOn ? @"ON" : @"OFF");
            return RACSignal.empty;
        }]];
    }];
    
    self.foldButton = [NSButton mm_make:^(NSButton * _Nonnull button) {
        [self.view addSubview:button];
        button.bordered = NO;
        button.imageScaling = NSImageScaleProportionallyDown;
        button.bezelStyle = NSBezelStyleRegularSquare;
        [button setButtonType:NSButtonTypeToggle];
        button.attributedTitle = [NSAttributedString mm_attributedStringWithString:@"展开" font:[NSFont systemFontOfSize:13] color:[NSColor mm_colorWithHexString:@"#007AFF"]];
        button.attributedAlternateTitle = [NSAttributedString mm_attributedStringWithString:@"折叠" font:[NSFont systemFontOfSize:13] color:[NSColor mm_colorWithHexString:@"#007AFF"]];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.offset(6);
            make.right.inset(6);
            make.height.mas_equalTo(32);
            make.width.mas_equalTo(38);
        }];
        mm_weakify(button)
        [button setRac_command:[[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(id  _Nullable input) {
            mm_strongify(button)
            [self foldQueryView:button.state == NSControlStateValueOn];
            NSLog(@"点击按钮 %@", button.state == NSControlStateValueOn ? @"ON" : @"OFF");
            return RACSignal.empty;
        }]];
    }];
    
    self.queryView = [QueryView mm_make:^(QueryView * _Nonnull view) {
        [self.view addSubview:view];
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.inset(12);
            make.top.equalTo(self.pinButton.mas_bottom).offset(2);
            make.height.equalTo(@176);
        }];
        [view setCopyActionBlock:^(QueryView * _Nonnull view) {
            [[NSPasteboard generalPasteboard] clearContents];
            [[NSPasteboard generalPasteboard] setString:view.textView.string forType:NSPasteboardTypeString];
        }];
        mm_weakify(self)
        [view setAudioActionBlock:^(QueryView * _Nonnull view) {
            mm_strongify(self);
            [self playAudioWithText:view.textView.string lang:Configuration.shared.from];
        }];
        [view setEnterActionBlock:^(QueryView * _Nonnull view) {
            mm_strongify(self);
            if (view.textView.string.length) {
                [self translate:view.textView.string];
            }
        }];
    }];
    
    self.fromLanguageButton = [PopUpButton mm_make:^(PopUpButton *  _Nonnull button) {
        [self.view addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.queryView.mas_bottom).offset(12);
            make.left.offset(12);
            make.width.mas_equalTo(100);
            make.height.mas_equalTo(25);
        }];
        [button updateMenuWithTitleArray:[self.languages mm_map:^id _Nullable(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj integerValue] == Language_auto) {
                return @"自动检测";
            }
            return LanguageDescFromEnum([obj integerValue]);
        }]];
        [button updateWithIndex:[self indexFromLangages:Configuration.shared.from]];
        mm_weakify(self);
        [button setMenuItemSeletedBlock:^(NSInteger index, NSString *title) {
            mm_strongify(self);
            Configuration.shared.from = [[self.languages objectAtIndex:index] integerValue];
        }];
    }];
    
    self.transformButton = [ImageButton mm_make:^(NSButton * _Nonnull button) {
        [self.view addSubview:button];
        button.bordered = NO;
        button.imageScaling = NSImageScaleProportionallyDown;
        button.bezelStyle = NSBezelStyleRegularSquare;
        [button setButtonType:NSButtonTypeToggle];
        button.image = [NSImage imageNamed:@"transform"];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.fromLanguageButton);
//            make.centerX.equalTo(self.queryView);
            make.left.equalTo(self.fromLanguageButton.mas_right).offset(30);
            make.width.equalTo(@40);
            make.height.equalTo(@40);
        }];
        mm_weakify(self)
        [button setRac_command:[[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(id  _Nullable input) {
            mm_strongify(self)
            Language from = Configuration.shared.from;
            Configuration.shared.from = Configuration.shared.to;
            Configuration.shared.to = from;
            [self.fromLanguageButton updateWithIndex:[self indexFromLangages:Configuration.shared.from]];
            [self.toLanguageButton updateWithIndex:[self indexFromLangages:Configuration.shared.to]];
            return RACSignal.empty;
        }]];
    }];
    
    self.toLanguageButton = [PopUpButton mm_make:^(PopUpButton *  _Nonnull button) {
        [self.view addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.top.equalTo(self.queryView.mas_bottom).offset(12);
//            make.right.inset(12);
            make.left.equalTo(self.transformButton.mas_right).offset(30);
            make.centerY.equalTo(self.transformButton);
            make.width.height.equalTo(self.fromLanguageButton);
            make.right.lessThanOrEqualTo(self.view.mas_right).offset(-12);
        }];
        [button updateMenuWithTitleArray:[self.languages mm_map:^id _Nullable(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj integerValue] == Language_auto) {
                return @"自动选择";
            }
            return LanguageDescFromEnum([obj integerValue]);
        }]];
        [button updateWithIndex:[self indexFromLangages:Configuration.shared.to]];
        mm_weakify(self);
        [button setMenuItemSeletedBlock:^(NSInteger index, NSString *title) {
            mm_strongify(self);
            Configuration.shared.to = [[self.languages objectAtIndex:index] integerValue];
        }];
    }];
    
    self.resultView = [ResultView mm_anyMake:^(ResultView *  _Nonnull view) {
        [self.view addSubview:view];
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.fromLanguageButton.mas_bottom).offset(12);
            make.left.right.equalTo(self.queryView);
            make.height.equalTo(@176);
            make.bottom.inset(12);
        }];
        mm_weakify(self)
        [view setAudioActionBlock:^(ResultView * _Nonnull view) {
            mm_strongify(self);
            [self playAudioWithText:view.textView.string lang:Configuration.shared.to];
        }];
        [view setCopyActionBlock:^(ResultView * _Nonnull view) {
            [[NSPasteboard generalPasteboard] clearContents];
            [[NSPasteboard generalPasteboard] setString:view.textView.string forType:NSPasteboardTypeString];
        }];
    }];
}

- (void)setupTranslate {
    self.baiduTranslate = [BaiduTranslate new];
    self.languages = @[
        @(Language_auto),
        @(Language_zh),
        @(Language_cht),
        @(Language_en),
        @(Language_yue),
        @(Language_wyw),
        @(Language_jp),
        @(Language_kor),
        @(Language_fra),
        @(Language_spa),
        @(Language_th),
        @(Language_ara),
        @(Language_ru),
        @(Language_pt),
        @(Language_de),
        @(Language_it),
        @(Language_el),
        @(Language_nl),
        @(Language_pl),
        @(Language_bul),
        @(Language_est),
        @(Language_dan),
        @(Language_fin),
        @(Language_cs),
        @(Language_rom),
        @(Language_slo),
        @(Language_swe),
        @(Language_hu),
        @(Language_vie),
    ];
    self.player = [[AVPlayer alloc] init];
    
    mm_weakify(self)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"translate" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
        mm_strongify(self)
        mm_weakify(self)
        [Selection getText:^(NSString * _Nullable text) {
            mm_strongify(self)
            if (text.length) {
                [self translate:text];
            }else {
                self.queryView.textView.string = @"";
                self.queryView.textView.string = @"";
            }
        }];
    }];
}

- (NSInteger)indexFromLangages:(Language)lang {
    return [[self.languages mm_where:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj integerValue] == lang) {
            *stop = YES;
            return YES;
        }
        return NO;
    }].firstObject integerValue];
}

- (void)playAudioWithText:(NSString *)text lang:(Language)lang {
    if (text.length) {
        mm_weakify(self)
        [self.baiduTranslate audio:text from:lang completion:^(NSString * _Nullable url, NSError * _Nullable error) {
            mm_strongify(self);
            if (!error) {
                [self playAudioWithURL:url];
            }
        }];
    }
}

- (void)playAudioWithURL:(NSString *)url {
    [self.player pause];
    [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:[NSURL URLWithString:url]]];
    [self.player play];
}

- (void)foldQueryView:(BOOL)isFold {
    self.queryView.hidden = isFold;
    self.fromLanguageButton.hidden = isFold;
    self.transformButton.hidden = isFold;
    self.toLanguageButton.hidden = isFold;
    [self.resultView mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (isFold) {
            make.top.equalTo(self.pinButton.mas_bottom).offset(2);
        }else {
            make.top.equalTo(self.fromLanguageButton.mas_bottom).offset(12);
        }
        make.left.right.equalTo(self.queryView);
        make.height.equalTo(@176);
        make.bottom.inset(12);
    }];
}

- (void)translate:(NSString *)text {
    self.queryView.textView.string = text;
    self.resultView.textView.string = @"查询中...";
    [self.baiduTranslate translate:text from:Configuration.shared.from to:Configuration.shared.to completion:^(TranslateResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            self.resultView.textView.string = [error.userInfo objectForKey:NSLocalizedDescriptionKey];
        }else {
            self.resultView.textView.string = [NSString mm_stringByCombineComponents:result.normalResults separatedString:@"\n"];
        }
    }];
}

- (void)updateHeight:(id)sender {
    
    //    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[textView font], NSFontAttributeName, nil];
    //    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[textView string] attributes:attributes];
    //    CGFloat height = [attributedString boundingRectWithSize:CGSizeMake(self.queryTextView.frame.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin].size.height;
    //    self.queryTextViewHeight.constant = height + 40;
    //    [self.view setNeedsLayout:YES];
}



@end
