#import "GameKitHelper.h"

@protocol MultiplayerNetworkingProtocol <NSObject>
- (void)matchEnded;
- (void)setCurrentPlayerIndex:(NSUInteger)index;
- (void)movePlayerAtIndex:(NSUInteger)index;
- (void)gameOver:(BOOL)player1Won;
- (void)setPlayerAliases:(NSArray*)playerAliases;
-(void)movePlayerOfNum:(NSInteger)index  clockwise:(BOOL)IsturnigClockwise;
@end
extern NSString *const gameHasBeenStarted;
@interface MultiplayerNetworking : NSObject<GameKitHelperDelegate>
@property (nonatomic, assign) id<MultiplayerNetworkingProtocol> delegate;
- (void)sendMove:(BOOL) isTurningClockwise;
- (void)sendGameEnd:(BOOL)player1Won;
@end
