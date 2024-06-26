// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @dev Interface for the Bingo Game contract
 */
interface IBingoGame {
    /**
     * @dev Thrown when a bingo game is over
     * */
    error GameIsOver();

    /**
     * @dev Thrown when a bingo game is not started
     * */
    error GameNotStarted();

    /**
     * @dev Thrown when a bingo game is not created
     * */
    error GameNotCreated();

    /**
     * @dev Thrown when msg.sender is not a player of a game
     * */
    error NotAPlayer();

    /**
     * @dev Thrown when a bingo game is in progress
     * */
    error GameInProgress();

    /**
     * @dev Thrown when player trice to join a game twice
     * */
    error CannotJoinTwice();

    /**
     * @dev Thrown when draw called before minimum Turn duration
     * */
    error WaitForNextTurn();

    /**
     * @dev Thrown when a bingo call fails
     * */
    error BingoCheckFailed();

    /**
     * @dev Emitted when a bingo game is created with index gameId
     * */
    event GameCreated(uint256 indexed gameId);

    /**
     * @dev Emintted when minimum Join duration for a game on BingoGame is updated
     * */
    event JoinDurationUpdated(uint256 indexed newMinJoinDuration);

    /**
     * @dev Emintted when minimum Turn duration for a game on BingoGame is updated
     * */
    event TurnDurationUpdated(uint256 indexed newMinTurnDuration);

    /**
     * @dev Emintted when Entry Fee to join a game on BingoGame is updated
     * */
    event EntryFeeUpdated(uint256 indexed newEntryFee);

    /**
     * @dev Emintted when A player with address "player" joins a game with game Index "gameIndex" on BingoGame is updated
     * */
    event PlayerJoined(uint256 indexed gameIndex, address indexed player);

    /**
     * @dev Emitted when a number is drawn for a game with game index "gameIndex"
     * */
    event Draw(uint256 indexed gameIndex, uint8 numberDrawn);

    /**
     * @dev Emitted when a game with game index "gameIndex" is finished
     **/
    event GameOver(uint256 indexed gameIndex, address winner, uint256 winnings);

    /**
     * @dev Updates the minumum join duration for games
     * Emits the JoinDurationUpdated event
     * Can only be called by the owner of the BingoGame contract
     * */
    function setJoinWindowDuration(uint256 _newJoinWindowDuration) external;

    /**
     * @dev Updates the minimum duration between draw
     * Emist TurnDurationUpdated event
     * Can only be called by the owner of the BingoGame contract
     * */
    function setMinimumTurnTime(uint256 _newMinimumTurnTime) external;

    /**
     * @dev Updates the entry fee to join a game
     * Emits EntryFeeUpdated event
     * Can only be called by the owner of the BingoGame contract
     * */
    function setEntryFee(uint256 _newEntryFee) external;

    /**
     * @dev Gives the board number for a game with game index "_gameIndex" of a player with address _player
     **/
    function getBoard(
        uint256 _gameIndex,
        address _player
    ) external view returns (uint8[24] memory _board);

    /**
     * @dev Creates a board for the sender and make him join a game with game index "_gameIndex"
     * Emits the PlayerJoined event
     * */
    function joinGame(uint256 _gameIndex) external;

    /**
     * @dev Draws a number for the game with game index "_gameIndex"
     * Emits the Draw event
     * */
    function draw(uint256 _gameIndex) external;

    // Todo : write description
    function createGame() external returns (uint256);

    /**
     * @dev Checks if the sender has won the game with game index "_gameIndex" with patter of index "patternIndex" with number with drawn on indexs drawIndexes
     * Emits GameOver event
     * */
    function bingo(uint256 _gameIndex) external;

    /**
     * @dev Get the entry fee for joining a game
     * @return entryFee The entry fee in wei
     * */
    function getEntryFee() external view returns (uint256);

    /**
     * @dev Get the duration of the window during which players can join a game
     * @return joinWindowDuration The duration in seconds
     * */
    function getJoinWindowDuration() external view returns (uint256);

    /**
     * @dev Get the minimum time required between two consecutive turns (draws) in a game
     * @return minimumTurnTime The minimum turn duration in seconds
     * */
    function getMinimumTurnTime() external view returns (uint256);

    /**
     * @dev Get the total number of games created
     * @return totalGames The total number of games created
     * */
    function getTotalGames() external view returns (uint256);
}
