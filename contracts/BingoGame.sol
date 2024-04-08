// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "contracts/Interfaces/IBingoGame.sol";
import "contracts/libs/libMask.sol";

/**
 * @title BingoGame contract for creating and playing multiple bingo games simultaneously
 * @author rishabh0x00
 * @dev This contract allows the creation and management of multiple bingo games concurrently.
 *      Players can join any number of games but are limited to one board per game.
 *      The contract creator can draw numbers, and players who complete bingo can claim their winnings, ending the game.
 */
contract BingoGame is Ownable, IBingoGame {
    using SafeERC20 for IERC20;
    using libMask for bytes32;

    struct BingoGameData {
        bool isGameComplete;
        bool isGameInProcess;
        uint64 startTime;
        uint64 lastDrawTime;
        uint256 gameEntryFee;
        uint256 playerCount;
        mapping(uint8 => bool) drawnNumbers; //check uint8
    }

    uint8[5][12] private _GRID_PATTERNS = [
        [0, 1, 2, 3, 4],
        [5, 6, 7, 8, 9],
        [10, 11, 12, 13, 0],
        [14, 15, 16, 17, 18],
        [19, 20, 21, 22, 23],
        [0, 5, 10, 14, 19],
        [1, 6, 11, 15, 20],
        [2, 7, 16, 21, 0],
        [3, 8, 12, 17, 22],
        [4, 9, 13, 18, 23],
        [0, 6, 17, 23, 0],
        [4, 8, 15, 19, 0]
    ];

    // The first 24 bytes are stored, but using bytes32 saves type conversion costs during operations
    // Mapping from gameId to player's Address to board (stored as bytes32)
    mapping(uint256 => mapping(address => bytes32)) private _playerBoard;

    uint256 private entryFee;
    IERC20 private immutable feeToken;

    // The host cannot start the first draw in a game until this duration has passed.
    // All players participating in the game should join before the first draw.
    uint256 private joinWindowDuration;

    // The host needs to wait for this duration between two consecutive draws.
    uint256 private minimumTurnTime;

    uint256 private totalGames;

    // Mapping from gameID to BingoGameData struct representing each game
    mapping(uint256 => BingoGameData) public games;

    /// @notice Constructor to initialize the BingoGame contract
    /// @param _feeToken Address of the fee token to be set
    /// @param _entryFee The entry fee per user per game
    /// @param _joinWindowDuration The minimum duration between the start of the game and the first draw
    /// @param _minimumTurnTime The minimum duration between two consecutive draws
    constructor(
        address _feeToken,
        uint256 _entryFee,
        uint256 _joinWindowDuration,
        uint256 _minimumTurnTime
    ) Ownable() {
        feeToken = IERC20(_feeToken);
        entryFee = _entryFee;
        joinWindowDuration = _joinWindowDuration;
        minimumTurnTime = _minimumTurnTime;
    }

    /// @notice Updates the minimum join duration before a game can start
    /// @param _newJoinWindowDuration New minimum join duration to set
    /// @dev Only the contract owner can execute this function
    function setJoinWindowDuration(
        uint256 _newJoinWindowDuration
    ) external onlyOwner {
        joinWindowDuration = _newJoinWindowDuration;
        emit JoinDurationUpdated(_newJoinWindowDuration);
    }

    /// @notice Updates the minimum turn duration between two consecutive draws
    /// @param _newMinimumTurnTime New minimum turn duration to set
    /// @dev Only the contract owner can execute this function
    function setMinimumTurnTime(
        uint256 _newMinimumTurnTime
    ) external onlyOwner {
        minimumTurnTime = _newMinimumTurnTime;
        emit TurnDurationUpdated(_newMinimumTurnTime);
    }

    /// @notice Updates the entry fee for a player to join a game
    /// @param _newEntryFee New entry fee
    /// @dev Only the contract owner can execute this function
    function setEntryFee(uint256 _newEntryFee) external onlyOwner {
        entryFee = _newEntryFee;
        emit EntryFeeUpdated(_newEntryFee);
    }

    /// @notice Returns the board of a player for a game
    /// @param _gameIndex Index of the game for which the user wants their board
    /// @param _player Address of the player to get the board of
    /// @return _board Numbers on the board
    function getBoard(
        uint256 _gameIndex,
        address _player
    ) external view returns (uint8[24] memory _board) {
        bytes32 boardBytes = _playerBoard[_gameIndex][_player];
        if (boardBytes == bytes32(0)) revert NotAPlayer();
        for (uint256 i; i < 24; i++) {
            _board[i] = uint8(boardBytes[31 - i]);
        }
    }

    /// @notice Creates a game of bingo
    /// @dev Increases the game counter and sets the game's start time and entry fee
    function createGame() external returns (uint256) {
        totalGames++; // First game index is 1
        games[totalGames].startTime = uint64(block.timestamp);
        // entryFee for a game cannot be changed once a game is created
        games[totalGames].gameEntryFee = entryFee;

        emit GameCreated(totalGames);
        return totalGames;
    }

    /// @notice Function for a player to join a game
    /// @param _gameIndex Index of the game to join
    function joinGame(uint256 _gameIndex) external {
        BingoGameData storage game = games[_gameIndex];
        if (game.isGameComplete) revert GameIsOver();
        if (game.startTime == 0) revert GameNotCreated();
        if (game.isGameInProcess) revert GameInProgress();
        if (_playerBoard[_gameIndex][msg.sender] != bytes32(0))
            revert CannotJoinTwice();

        uint256 playerCount = game.playerCount;
        bytes32 blockHash = blockhash(block.number - 1);

        // The board index starts from 0.
        // PlayerCount is used to ensure that no board collision happens in a single block for a given gameIndex.
        // GameIndex is used to achieve different boards with the same player count and block number.
        _playerBoard[_gameIndex][msg.sender] = keccak256(
            abi.encodePacked(blockHash, playerCount, _gameIndex)
        ).keepFirst24Bytes();
        games[_gameIndex].playerCount++;

        feeToken.safeTransferFrom(msg.sender, address(this), game.gameEntryFee);

        emit PlayerJoined(_gameIndex, msg.sender);
    }

    /// @notice Function to draw a number for a game
    /// @param _gameIndex Index of the game to draw a number for
    function draw(uint256 _gameIndex) external {
        uint64 currentTime = uint64(block.timestamp);
        BingoGameData storage game = games[_gameIndex];
        if (game.isGameComplete) revert GameIsOver();

        if (game.isGameInProcess) {
            if (currentTime < game.lastDrawTime + minimumTurnTime)
                revert WaitForNextTurn();
        } else {
            if (currentTime < game.startTime + joinWindowDuration)
                revert GameNotStarted();
            game.isGameInProcess = true;
        }

        uint8 numberDrawn = uint8(blockhash(block.number - 1)[0]);
        game.drawnNumbers[numberDrawn] = true;
        game.lastDrawTime = currentTime;

        emit Draw(_gameIndex, numberDrawn);
    }

    /// @notice Function for players to call bingo if they win
    /// @param _gameIndex Index of the game where the player wants to call bingo
    function bingo(uint256 _gameIndex) public {
        BingoGameData storage game = games[_gameIndex];
        bytes32 board = _playerBoard[_gameIndex][msg.sender];
        require(board != bytes32(0), "Bingo: not a player");
        bool result = true;

        for (uint256 j; j < 12; j++) {
            uint8[5] memory pattern = _GRID_PATTERNS[j];
            uint256 patternLength = (j == 2 || j == 7 || j == 10 || j == 11)
                ? 4
                : 5;

            for (uint256 i; i < patternLength; i++) {
                result =
                    result &&
                    game.drawnNumbers[uint8(board[31 - pattern[i]])];
            }
            if (result) break;
            if (j < 11) result = true;
        }
        if (!result) revert BingoCheckFailed();

        uint256 totalFee = game.gameEntryFee * game.playerCount;
        feeToken.safeTransfer(msg.sender, totalFee);

        games[_gameIndex].isGameComplete = true;
        emit GameOver(_gameIndex, msg.sender, totalFee);
    }

    /// @notice Retrieves the entry fee for joining a game
    /// @return entryFee The entry fee in wei
    function getEntryFee() external view returns (uint256) {
        return entryFee;
    }

    /// @notice Get the duration of the window during which players can join a game
    /// @return joinWindowDuration The duration in seconds
    function getJoinWindowDuration() external view returns (uint256) {
        return joinWindowDuration;
    }

    /// @notice Get the minimum time required between two consecutive turns (draws) in a game
    /// @return minimumTurnTime The minimum turn duration in seconds
    function getMinimumTurnTime() external view returns (uint256) {
        return minimumTurnTime;
    }

    /// @notice Get the total number of games created
    /// @return totalGames The total number of games created
    function getTotalGames() external view returns (uint256) {
        return totalGames;
    }
}
