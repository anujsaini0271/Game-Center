# Game-Center
follow this tutorial

www.raywenderlich.com/60980/game-center-tutorial-how-to-make-a-simple-multiplayer-game-with-sprite-kit-part-1


some basic code for using Game Center in Your Game.
this code shows some basic feature of Game Center.
please follow the Chain of methods calling to understand the code 

to  start authentication you need to call method from the class from where you want to call it.

[[GameKitHelper sharedGameKitHelper] authenticateLocalPlayer];

generally people write it in rootviewController to authenticate player.

once it is autheticated there will be a welcome message.

then call 
- (void)findMatchWithMinPlayers:(int)minPlayers maxPlayers:(int)maxPlayers
                 viewController:(UIViewController *)viewController
                       delegate:(id<GameKitHelperDelegate>)delegate 

to find match for players

if you want to find player of perticular group then set a number to that group and set

GKMatchRequest *request = [[GKMatchRequest alloc] init];
    request.playerGroup = numberOfGroup;
    
then it will find only those player with that group number.

www.raywenderlich.com/60980/game-center-tutorial-how-to-make-a-simple-multiplayer-game-with-sprite-kit-part-1
then it will start sending message to other player in multiplayer Player NetWorking.



     
     
