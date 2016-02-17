#import "MultiplayerNetworking.h"
#define playerIdKey @"PlayerId"
#define randomNumberKey @"randomNumber"
#import "gVars.h"
NSString *const gameHasBeenStarted=@"gameHasBeenStarted";

typedef NS_ENUM(NSUInteger, playerNum) {
    player1=1,
    player2,
    player3,
    player4
 };
typedef NS_ENUM(NSUInteger, GameState) {
    kGameStateWaitingForMatch = 0,
    kGameStateWaitingForRandomNumber,
    kGameStateWaitingForStart,
    kGameStateActive,
    kGameStateDone
};

typedef NS_ENUM(NSUInteger, MessageType) {
    kMessageTypeRandomNumber = 0,
    kMessageTypeGameBegin,
    kMessageTypeMove,
    kMessageTypeGameOver
};

typedef struct {
    MessageType messageType;
} Message;

typedef struct {
    Message message;
    uint32_t randomNumber;
} MessageRandomNumber;

typedef struct {
    Message message;
} MessageGameBegin;

typedef struct {
    Message message;
    BOOL turnClockwise;
} MessageMove;

typedef struct {
    Message message;
    BOOL player1Won;
} MessageGameOver;


@implementation MultiplayerNetworking {
    uint32_t _ourRandomNumber;
    GameState _gameState;
    BOOL _isPlayer1, _receivedAllRandomNumbers;
    NSMutableDictionary *_dictionaryGlobal;
    NSMutableArray *_orderOfPlayers;
};

- (id)init
{
    NSLog(@"multiplayerNetworking/init");
    if (self = [super init]) {
        _dictionaryGlobal=[[NSMutableDictionary alloc] init];
        _ourRandomNumber = arc4random();
        _gameState = kGameStateWaitingForMatch;
        _orderOfPlayers = [NSMutableArray array];
        [_orderOfPlayers addObject:@{playerIdKey : [GKLocalPlayer localPlayer].playerID,
                                     randomNumberKey : @(_ourRandomNumber)}];
    }
    return self;
}


- (void)sendGameEnd:(BOOL)player1Won {
    NSLog(@"multiplayerNetworking/sendGameEnd");
    MessageGameOver message;
    message.message.messageType = kMessageTypeGameOver;
    message.player1Won = player1Won;
    NSData *data = [NSData dataWithBytes:&message length:sizeof(MessageGameOver)];
    [self sendData:data];
}

- (void)sendData:(NSData*)data
{
    NSLog(@"multiplayerNetworking/sendData");
    NSError *error;
    GameKitHelper *gameKitHelper = [GameKitHelper sharedGameKitHelper];
    
    BOOL success = [gameKitHelper.match
                    sendDataToAllPlayers:data
                    withDataMode:GKMatchSendDataReliable
                    error:&error];
    
    if (!success) {
        NSLog(@"Error sending data:%@", error.localizedDescription);
        [self matchEnded];
    }
}

-(void)processReceivedRandomNumber:(NSDictionary*)randomNumberDetails {
    NSLog(@"multiplayerNetworking/processRecieveNumber");
    if([_orderOfPlayers containsObject:randomNumberDetails]) {
        [_orderOfPlayers removeObjectAtIndex:
         [_orderOfPlayers indexOfObject:randomNumberDetails]];
    }
    //2
    [_orderOfPlayers addObject:randomNumberDetails];
    
    //3
    NSSortDescriptor *sortByRandomNumber =
    [NSSortDescriptor sortDescriptorWithKey:randomNumberKey
                                  ascending:NO];
    NSArray *sortDescriptors = @[sortByRandomNumber];
    [_orderOfPlayers sortUsingDescriptors:sortDescriptors];
    
    //4
    if ([self allRandomNumbersAreReceived]) {
        _receivedAllRandomNumbers = YES;
    }
}


- (BOOL)allRandomNumbersAreReceived
{
    NSLog(@"multiplayerNetworking/allRandomNumberAreReceived");
    NSMutableArray *receivedRandomNumbers =
    [NSMutableArray array];
    
    for (NSDictionary *dict in _orderOfPlayers) {
        [receivedRandomNumbers addObject:dict[randomNumberKey]];
    }
    
    NSArray *arrayOfUniqueRandomNumbers = [[NSSet setWithArray:receivedRandomNumbers] allObjects];
    
    if (arrayOfUniqueRandomNumbers.count ==
        [GameKitHelper sharedGameKitHelper].match.playerIDs.count + 1) {
        return YES;
    }
    return NO;
}


- (BOOL)isLocalPlayerPlayer1
{
    NSLog(@"multiplayerNetworking/isLocalPlayerPlayer1");
    NSDictionary *dictionary = _orderOfPlayers[0];
    if ([dictionary[playerIdKey]
         isEqualToString:[GKLocalPlayer localPlayer].playerID]) {
        NSLog(@"I'm player 1");
        return YES;
    }
    
    return NO;
}


#pragma mark GameKitHelper delegate methods

- (void)matchStarted
{
    NSLog(@"GameKitHelperDelegate/matchStarted");
    
    
    NSLog(@"Match has started successfully");
    if (_receivedAllRandomNumbers) {
        _gameState = kGameStateWaitingForStart;
    } else {
        _gameState = kGameStateWaitingForRandomNumber;
    }
    [self sendRandomNumber];
    [self tryStartGame];
}

- (void)sendRandomNumber
{
    NSLog(@"multiplayerNetworking/sendrandomNumber");
    MessageRandomNumber message;
    message.message.messageType = kMessageTypeRandomNumber;
    message.randomNumber = _ourRandomNumber;
    NSData *data = [NSData dataWithBytes:&message length:sizeof(MessageRandomNumber)];
    [self sendData:data];
}

- (void)sendGameBegin {
    NSLog(@"multiplayerNetworking/sendGameBegin");
    
    MessageGameBegin message;
    message.message.messageType = kMessageTypeGameBegin;
    NSData *data = [NSData dataWithBytes:&message length:sizeof(MessageGameBegin)];
    [self sendData:data];
    [self assignPlayerToEachId];
    NSLog(@"%@",_orderOfPlayers);
    [[NSNotificationCenter defaultCenter] postNotificationName:gameHasBeenStarted object:self];
}


- (void)sendMove:(BOOL)isTurningClockwise {
    NSLog(@"multiplayerNetworking/sendMove");
    MessageMove messageMove;
    messageMove.message.messageType = kMessageTypeMove;
    messageMove.turnClockwise=isTurningClockwise;
    NSData *data = [NSData dataWithBytes:&messageMove
                                  length:sizeof(MessageMove)];
    [self sendData:data];
}

- (void)tryStartGame
{
    NSLog(@"multiplayerNetworking/tryStartGame");
    if (_isPlayer1 && _gameState == kGameStateWaitingForStart) {
        _gameState = kGameStateActive;
        [self sendGameBegin];
        [self.delegate setCurrentPlayerIndex:0];
        [self processPlayerAliases];
    }
}


- (void)processPlayerAliases {
    NSLog(@"multiplayerNetworking/processPlayerAliases");
    if ([self allRandomNumbersAreReceived]) {
        NSMutableArray *playerAliases = [NSMutableArray arrayWithCapacity:_orderOfPlayers.count];
        for (NSDictionary *playerDetails in _orderOfPlayers) {
            NSString *playerId = playerDetails[playerIdKey];
            [playerAliases addObject:((GKPlayer*)[GameKitHelper sharedGameKitHelper].playersDict[playerId]).alias];
        }
        if (playerAliases.count > 0) {
            [self.delegate setPlayerAliases:playerAliases];
        }
    }
}


- (NSUInteger)indexForLocalPlayer
{
    NSLog(@"multiplayerNetworking/indexForLocalPlayer");
    NSString *playerId = [GKLocalPlayer localPlayer].playerID;
    
    return [self indexForPlayerWithId:playerId];
}

- (NSUInteger)indexForPlayerWithId:(NSString*)playerId
{
    NSLog(@"multiplayerNetworking/indexForPlayerWithId");
    __block NSUInteger index = -1;
    [_orderOfPlayers enumerateObjectsUsingBlock:^(NSDictionary
                                                  *obj, NSUInteger idx, BOOL *stop){
        NSString *pId = obj[playerIdKey];
        if ([pId isEqualToString:playerId]) {
            index = idx;
            *stop = YES;
        }
    }];
    return index;
}

- (void)matchEnded {
    NSLog(@"Match has ended");
    [_delegate matchEnded];
}

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID {
    //1
    Message *message = (Message*)[data bytes];
    if (message->messageType == kMessageTypeRandomNumber) {
        MessageRandomNumber *messageRandomNumber = (MessageRandomNumber*)[data bytes];
        
        NSLog(@"Received random number:%d", messageRandomNumber->randomNumber);
        
        BOOL tie = NO;
        if (messageRandomNumber->randomNumber == _ourRandomNumber) {
            //2
            NSLog(@"Tie");
            tie = YES;
            _ourRandomNumber = arc4random();
            [self sendRandomNumber];
        } else {
            //3
            NSDictionary *dictionary = @{playerIdKey : playerID,
                                         randomNumberKey : @(messageRandomNumber->randomNumber)};
            [self processReceivedRandomNumber:dictionary];
        }
        
        //4
        if (_receivedAllRandomNumbers) {
            _isPlayer1 = [self isLocalPlayerPlayer1];
        }
        
        if (!tie && _receivedAllRandomNumbers) {
            //5
            if (_gameState == kGameStateWaitingForRandomNumber) {
                _gameState = kGameStateWaitingForStart;
            }
            [self tryStartGame];
        }
    }
    
    else if (message->messageType == kMessageTypeGameBegin) {
        NSLog(@"Begin game message received");
        _gameState = kGameStateActive;
        [self.delegate setCurrentPlayerIndex:[self indexForLocalPlayer]];
        [self processPlayerAliases];
        [self assignPlayerToEachId];
        [[NSNotificationCenter defaultCenter] postNotificationName:gameHasBeenStarted object:nil];
    } else if (message->messageType == kMessageTypeMove) {
        NSLog(@"Move message received");
        MessageMove *messageMove = (MessageMove*)[data bytes];
        
        [self.delegate  movePlayerOfNum:(NSInteger)[_dictionaryGlobal objectForKey:playerIdKey] clockwise:messageMove->turnClockwise];
    } else if(message->messageType == kMessageTypeGameOver) {
        NSLog(@"Game over message received");
        MessageGameOver * messageGameOver = (MessageGameOver *) [data bytes];
        [self.delegate gameOver:messageGameOver->player1Won];
    }
}

-(void)assignPlayerToEachId
{NSDictionary *dictionary;
    int count=0;
    if([gVars sharedInstance].player1IsHuman)
    {
        dictionary=_orderOfPlayers[count];
        [_dictionaryGlobal setObject:[NSNumber numberWithInteger:player1] forKey:dictionary[playerIdKey]];
        
        count++;
    }
    if([gVars sharedInstance].player2IsHuman)
    {
        dictionary=_orderOfPlayers[count];
        [_dictionaryGlobal setObject:[NSNumber numberWithInteger:player2] forKey:dictionary[playerIdKey]];
        count++;
    }
    if([gVars sharedInstance].player3IsHuman)
    {
        dictionary=_orderOfPlayers[count];
        [_dictionaryGlobal setObject:[NSNumber numberWithInteger:player3] forKey:dictionary[playerIdKey]];
        count++;
    }
    if([gVars sharedInstance].player4IsHuman)
    {
        dictionary=_orderOfPlayers[count];
        [_dictionaryGlobal setObject:[NSNumber numberWithInteger:player4] forKey:dictionary[playerIdKey]];
        count++;
    }
    

}
@end
