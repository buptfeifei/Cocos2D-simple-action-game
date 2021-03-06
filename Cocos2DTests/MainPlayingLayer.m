//
//  MainPlayingLayer.m
//  Cocos2DTests
//
//  Created by Zhenia on 8/21/12.
//  Copyright 111 Minutes 2012. All rights reserved.
//


// Import the interfaces
#import <AVFoundation/AVFoundation.h>
#import "MainPlayingLayer.h"

// Needed to obtain the Navigation Controller
#import "AppDelegate.h"
#import "GameOverLayer.h"
#import "GameAudioEngine.h"
#import "SimpleAudioEngine.h"

#pragma mark defines

#define TARGET_TAG 1
#define PROJECTILE_TAG 2

#pragma mark - PlayingLayer

// MainPlayingLayer implementation
@implementation MainPlayingLayer

// Helper class method that creates a Scene with the MainPlayingLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	MainPlayingLayer *layer = [MainPlayingLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	[_player release];
    _player = nil;

    [_targets release];
    _targets = nil;

    [_projectiles release];
    _projectiles = nil;
	
	// don't forget to call "super dealloc"
    [_scoreLabel release];
    _scoreLabel = nil;

    [_nextProjectile release], _nextProjectile = nil;

    [super dealloc];
}

// on "init" you need to initialize your instance
-(id) init
{
    if( (self=[super init]) ) {

        self.isTouchEnabled = YES;
        _targets = [NSMutableArray new];
        _projectiles = [NSMutableArray new];

        _score = 0;
        _lostTargetsCount = 0;

        [self createScoreLabel];

        [self createPlayer];

        [self schedule:@selector(gameLoop:) interval:1.0];
        [self schedule:@selector(updateGame:)];

        [[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"background-music.caf"];
//        [self createMenu];


    }
    return self;
}

- (void)createScoreLabel {

    // create and initialize a Label
    CGFloat fontSize = 16;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        fontSize = 24;
    }
    _scoreLabel = [[CCLabelTTF alloc] initWithString:@"Score: 0" fontName:@"Marker Felt" fontSize:16];

    [self updateScore];

    // add the label as a child to this Layer
    [self addChild:_scoreLabel];
}

- (void)createPlayer {
// ask director for the window size
    CGSize size = [[CCDirector sharedDirector] winSize];

    _player = [[CCSprite spriteWithFile:@"Player.png"] retain];
    _player.position = ccp(_player.contentSize.width/2, size.height/2);

    [self addChild: _player];
}

#pragma mark logic

- (void)createMenu {

    CGSize size = [[CCDirector sharedDirector] winSize];

    // Leaderboards and Achievements
    //

    // Default font size will be 28 points.
    [CCMenuItemFont setFontSize:28];

    // Achievement Menu Item using blocks
    CCMenuItem *itemAchievement = [CCMenuItemFont itemWithString:@"Achievements" block:^(id sender) {


        GKAchievementViewController *achivementViewController = [[GKAchievementViewController alloc] init];
        achivementViewController.achievementDelegate = self;

        AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];

        [[app navController] presentModalViewController:achivementViewController animated:YES];

        [achivementViewController release];
    }
    ];

    // Leaderboard Menu Item using blocks
    CCMenuItem *itemLeaderboard = [CCMenuItemFont itemWithString:@"Leaderboard" block:^(id sender) {


        GKLeaderboardViewController *leaderboardViewController = [[GKLeaderboardViewController alloc] init];
        leaderboardViewController.leaderboardDelegate = self;

        AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];

        [[app navController] presentModalViewController:leaderboardViewController animated:YES];

        [leaderboardViewController release];
    }
    ];

    CCMenu *menu = [CCMenu menuWithItems:itemAchievement, itemLeaderboard, nil];

    [menu alignItemsHorizontallyWithPadding:20];
    [menu setPosition:ccp( size.width/2, size.height/2 - 50)];

    // Add the menu to the layer
    [self addChild:menu];
}

- (void)addTarget {

    CCSprite *target = [CCSprite spriteWithFile:@"Target.png"];
    target.tag = TARGET_TAG;
    [_targets addObject:target];

    CGSize size = [[CCDirector sharedDirector] winSize];
    int minY = (int) (target.contentSize.height/2);
    int maxY = (int) (size.height - target.contentSize.height/2);
    int rangeY = maxY - minY;
    int actualY = (arc4random() % rangeY) + minY;

    target.position = ccp(size.width - target.contentSize.height/2, actualY);
    [self addChild:target];

    //Determine speed of target
    int minDuration = 2;
    int maxDuration = 4;
    int rangeDuration = maxDuration - minDuration;
    int actualDuration = (arc4random() % rangeDuration) + minDuration;

    // Create actions
    id actionMove = [CCMoveTo actionWithDuration:actualDuration
                                        position:ccp(-target.contentSize.width/2, actualY)];
    id actionMoveDone = [CCCallFuncN actionWithTarget:self selector:@selector(spriteMoveFinished:)];
    [target runAction:[CCSequence actions:actionMove, actionMoveDone, nil]];

}

- (void)spriteMoveFinished:(id)sender {
    CCSprite *sprite = (CCSprite *)sender;
    if (sprite.tag == TARGET_TAG) { // target
        [_targets removeObject:sprite];
        _lostTargetsCount++;
        if (_lostTargetsCount > 2) {
            [[SimpleAudioEngine sharedEngine] stopBackgroundMusic];
            [[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:1 scene:[GameOverLayer scene]]];
        }
    } else if (sprite.tag == PROJECTILE_TAG) { // projectile
        [_projectiles removeObject:sprite];
    }
}

- (void)gameLoop:(ccTime)dt {
    [self addTarget];
}

- (void)updateGame:(ccTime)dt {
    NSMutableArray *projectilesToDelete = [NSMutableArray new];
    for (CCSprite *projectile in _projectiles) {
        CGRect projectileRect = CGRectMake(
                projectile.position.x - projectile.contentSize.width/2,
                projectile.position.y - projectile.contentSize.height/2,
                projectile.contentSize.width,
                projectile.contentSize.height);

        NSMutableArray *targetsToDelete = [NSMutableArray new];
        for (CCSprite *target in _targets) {
            CGRect targetRect = CGRectMake(
                    target.position.x - target.contentSize.width/2,
                    target.position.y - target.contentSize.height/2,
                    target.contentSize.width,
                    target.contentSize.height);

            if (CGRectIntersectsRect(projectileRect, targetRect)) {
                [targetsToDelete addObject:target];
            }
        }

        if (targetsToDelete.count > 0) {
            [projectilesToDelete addObject:projectile];
        }

        for (CCSprite *target in targetsToDelete) {
            [_targets removeObject:target];
            [self removeChild:target cleanup:YES];
            _score++;
        }


        [targetsToDelete release];
    }

    for (CCSprite *projectile in projectilesToDelete) {
        [_projectiles removeObject:projectile];
        [self removeChild:projectile cleanup:YES];
    }
    [projectilesToDelete release];

    [self updateScore];
}

- (void)updateScore {

    [_scoreLabel setString:[NSString stringWithFormat:@"Score: %d", _score]];

    // ask director for the window size
    CGSize size = [[CCDirector sharedDirector] winSize];

    // position the label on the center of the screen
    _scoreLabel.position =  ccp( size.width - _scoreLabel.contentSize.width/2 , size.height - _scoreLabel.contentSize.height/2 );
}

#pragma mark Cocos2D touches

- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

    if (_nextProjectile != nil) return;

    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:[touch view]];
    location = [[CCDirector sharedDirector] convertToGL:location];

    CGSize size = [[CCDirector sharedDirector] winSize];
    _nextProjectile = [[CCSprite spriteWithFile:@"Projectile.png"] retain];
    _nextProjectile.position = ccp(_nextProjectile.contentSize.width, size.height/2);
    _nextProjectile.tag = PROJECTILE_TAG;

    int offsetX = (int) (location.x - _nextProjectile.position.x);
    int offsetY = (int) (location.y - _nextProjectile.position.y);

    // Bail out if we are shooting down or backwards
    if (offsetX <=0) {
        [_nextProjectile release];
        _nextProjectile = nil;
        return;
    }

    //determine real coordinate to shoot
    int realX = (int) (size.width + _nextProjectile.contentSize.width/2);
    float ratio = (float)offsetY / (float) offsetX;
    int realY = (int) ((realX * ratio) + _nextProjectile.position.y);
    CGPoint realDestination = ccp(realX, realY);

    // Determine the length of how far we're shooting
    int offRealX = (int) (realX - _nextProjectile.position.x);
    int offRealY = (int) (realY - _nextProjectile.position.y);
    float length = sqrtf((offRealX*offRealX)+(offRealY*offRealY));
    float velocity = 480/1; // 480pixels/1sec
    float realMoveDuration = length/velocity;

    // Determine angle to face
    float angleRadians = atanf((float)offRealY / (float)offRealX);
    float angleDegrees = CC_RADIANS_TO_DEGREES(angleRadians);
    float cocosAngle = -1 * angleDegrees;

    float rotateSpeed = (float) (0.5 / M_PI); // Would take 0.5 seconds to rotate 0.5 radians, or half a circle
    float rotateDuration = (float) fabs(angleRadians * rotateSpeed);

    [_player runAction:[CCSequence actions:[CCRotateTo actionWithDuration:rotateDuration angle:cocosAngle],
                                           [CCCallFunc actionWithTarget:self selector:@selector(finishShoot)], nil]];

    [_nextProjectile runAction:[CCSequence actions:
            [CCMoveTo actionWithDuration:realMoveDuration position:realDestination],
            [CCCallFuncN actionWithTarget:self selector:@selector(spriteMoveFinished:)], nil]];

    [[SimpleAudioEngine sharedEngine] playEffect:@"pew-pew.caf"];
}

- (void)finishShoot {
    [_projectiles addObject:_nextProjectile];
    [self addChild:_nextProjectile];

    [_nextProjectile release];
    _nextProjectile = nil;
}


#pragma mark GameKit delegate

-(void) achievementViewControllerDidFinish:(GKAchievementViewController *)viewController
{
	AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];
	[[app navController] dismissModalViewControllerAnimated:YES];
}

-(void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController
{
	AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];
	[[app navController] dismissModalViewControllerAnimated:YES];
}
@end
