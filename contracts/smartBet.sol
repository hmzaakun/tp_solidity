// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SmartBet {
    struct User {
        string pseudo;
        bool isRegistered;
    }

    struct Bet {
        uint matchId;
        uint predictedScoreHome;
        uint predictedScoreAway;
        address bettor;
    }

    struct Match {
        uint date;
        uint scoreHome;
        uint scoreAway;
        bool isFinished;
    }

    address public admin;
    uint public entryFee;
    uint public totalPool;
    mapping(address => User) public users;
    mapping(uint => Match) public matches; // clé : ID du match
    mapping(uint => Bet[]) public matchBets; // paris pour chaque match
    uint[] public matchIds;

    event UserRegistered(address user, string pseudo);
    event BetPlaced(address user, uint matchId, uint predictedScoreHome, uint predictedScoreAway);
    event WinnersPaid(uint matchId);
    event MatchAdded(uint matchId, uint date);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this.");
        _;
    }

    constructor(uint _entryFee) {
        admin = msg.sender;
        entryFee = _entryFee;
    }

    function registerUser(string calldata _pseudo) external {
        require(!users[msg.sender].isRegistered, "User already registered.");
        users[msg.sender] = User(_pseudo, true);
        emit UserRegistered(msg.sender, _pseudo);
    }

    function placeBet(uint _matchId, uint _predictedScoreHome, uint _predictedScoreAway) external payable {
        require(msg.value == entryFee, "Incorrect entry fee.");
        require(users[msg.sender].isRegistered, "User not registered.");
        require(matches[_matchId].date != 0 && !matches[_matchId].isFinished, "Match not available for betting.");
        
        matchBets[_matchId].push(Bet({
            matchId: _matchId,
            predictedScoreHome: _predictedScoreHome,
            predictedScoreAway: _predictedScoreAway,
            bettor: msg.sender
        }));
        totalPool += msg.value;
        emit BetPlaced(msg.sender, _matchId, _predictedScoreHome, _predictedScoreAway);
    }

    function addMatch(uint _matchId, uint _date) external onlyAdmin {
        require(matches[_matchId].date == 0, "Match already exists.");
        matches[_matchId] = Match(_date, 0, 0, false);
        matchIds.push(_matchId);
        emit MatchAdded(_matchId, _date);
    }

    function setMatchResult(uint _matchId, uint _scoreHome, uint _scoreAway) external onlyAdmin {
        require(matches[_matchId].date != 0, "Match does not exist.");
        matches[_matchId].isFinished = true;
        matches[_matchId].scoreHome = _scoreHome;
        matches[_matchId].scoreAway = _scoreAway;
        determineWinners(_matchId);
    }

    function determineWinners(uint _matchId) private {
        uint countWinners = 0;
        for (uint i = 0; i < matchBets[_matchId].length; i++) {
            if (matchBets[_matchId][i].predictedScoreHome == matches[_matchId].scoreHome &&
                matchBets[_matchId][i].predictedScoreAway == matches[_matchId].scoreAway) {
                countWinners++;
            }
        }

        uint effectiveWinners = countWinners > 5 ? 5 : countWinners;
        if (countWinners > 0) {
            uint winnerShare = totalPool / effectiveWinners;
            uint winnersPaid = 0;
            for (uint i = 0; i < matchBets[_matchId].length && winnersPaid < effectiveWinners; i++) {
                if (matchBets[_matchId][i].predictedScoreHome == matches[_matchId].scoreHome &&
                    matchBets[_matchId][i].predictedScoreAway == matches[_matchId].scoreAway) {
                    payable(matchBets[_matchId][i].bettor).transfer(winnerShare);
                    winnersPaid++;
                }
            }
            totalPool -= winnerShare * winnersPaid;
            emit WinnersPaid(_matchId);
        }
    }
}
