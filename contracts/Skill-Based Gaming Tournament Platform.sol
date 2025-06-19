// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Skill-Based Gaming Tournament Platform
 * @dev A decentralized platform for organizing and managing skill-based gaming tournaments
 */
contract Project {
    
    address public owner;
    uint256 public tournamentCounter;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5;
    
    struct Tournament {
        uint256 id;
        string name;
        address organizer;
        uint256 entryFee;
        uint256 prizePool;
        uint256 maxParticipants;
        uint256 currentParticipants;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isCompleted;
        address winner;
    }
    
    struct Player {
        uint256 totalTournamentsPlayed;
        uint256 totalWinnings;
        uint256 skillRating;
        bool isRegistered;
    }
    
    mapping(uint256 => Tournament) public tournaments;
    mapping(address => Player) public players;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(uint256 => mapping(address => bool)) public isParticipant;
    mapping(uint256 => address[]) public participantsList;
    
    event TournamentCreated(uint256 indexed tournamentId, string name, address indexed organizer);
    event PlayerJoined(uint256 indexed tournamentId, address indexed player);
    event TournamentCompleted(uint256 indexed tournamentId, address indexed winner, uint256 prize);
    event PlayerRegistered(address indexed player);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier onlyRegistered() {
        require(players[msg.sender].isRegistered, "Not registered");
        _;
    }
    
    modifier validTournament(uint256 _id) {
        require(_id > 0 && _id <= tournamentCounter, "Invalid tournament");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Create Tournament
     */
    function createTournament(
        string memory _name,
        uint256 _entryFee,
        uint256 _maxParticipants,
        uint256 _duration
    ) external onlyRegistered {
        require(bytes(_name).length > 0, "Empty name");
        require(_entryFee > 0, "Zero entry fee");
        require(_maxParticipants >= 2, "Min 2 participants");
        require(_duration > 0, "Zero duration");
        
        tournamentCounter++;
        
        Tournament storage newTournament = tournaments[tournamentCounter];
        newTournament.id = tournamentCounter;
        newTournament.name = _name;
        newTournament.organizer = msg.sender;
        newTournament.entryFee = _entryFee;
        newTournament.prizePool = 0;
        newTournament.maxParticipants = _maxParticipants;
        newTournament.currentParticipants = 0;
        newTournament.startTime = block.timestamp;
        newTournament.endTime = block.timestamp + _duration;
        newTournament.isActive = true;
        newTournament.isCompleted = false;
        newTournament.winner = address(0);
        
        emit TournamentCreated(tournamentCounter, _name, msg.sender);
    }
    
    /**
     * @dev Core Function 2: Join Tournament
     */
    function joinTournament(uint256 _tournamentId) 
        external 
        payable 
        onlyRegistered 
        validTournament(_tournamentId) 
    {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.isActive, "Not active");
        require(!tournament.isCompleted, "Already completed");
        require(block.timestamp < tournament.endTime, "Registration ended");
        require(tournament.currentParticipants < tournament.maxParticipants, "Tournament full");
        require(!isParticipant[_tournamentId][msg.sender], "Already joined");
        require(msg.value == tournament.entryFee, "Wrong entry fee");
        
        isParticipant[_tournamentId][msg.sender] = true;
        participantsList[_tournamentId].push(msg.sender);
        tournament.currentParticipants++;
        tournament.prizePool += msg.value;
        
        players[msg.sender].totalTournamentsPlayed++;
        
        emit PlayerJoined(_tournamentId, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Complete Tournament
     */
    function completeTournament(uint256 _tournamentId, address _winner) 
        external 
        validTournament(_tournamentId) 
    {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(msg.sender == tournament.organizer || msg.sender == owner, "Not authorized");
        require(tournament.isActive, "Not active");
        require(!tournament.isCompleted, "Already completed");
        require(isParticipant[_tournamentId][_winner], "Winner not participant");
        require(tournament.currentParticipants >= 2, "Need min 2 participants");
        
        uint256 platformFee = (tournament.prizePool * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 winnerPrize = tournament.prizePool - platformFee;
        
        tournament.isCompleted = true;
        tournament.isActive = false;
        tournament.winner = _winner;
        
        players[_winner].totalWinnings += winnerPrize;
        players[_winner].skillRating += 10;
        
        // Update other participants
        address[] memory participants = participantsList[_tournamentId];
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] != _winner && players[participants[i]].skillRating > 5) {
                players[participants[i]].skillRating -= 1;
            }
        }
        
        pendingWithdrawals[_winner] += winnerPrize;
        pendingWithdrawals[owner] += platformFee;
        
        emit TournamentCompleted(_tournamentId, _winner, winnerPrize);
    }
    
    /**
     * @dev Register as a player
     */
    function registerPlayer() external {
        require(!players[msg.sender].isRegistered, "Already registered");
        
        players[msg.sender] = Player({
            totalTournamentsPlayed: 0,
            totalWinnings: 0,
            skillRating: 100,
            isRegistered: true
        });
        
        emit PlayerRegistered(msg.sender);
    }
    
    /**
     * @dev Withdraw winnings
     */
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds");
        
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Get tournament participants
     */
    function getTournamentParticipants(uint256 _tournamentId) 
        external 
        view 
        validTournament(_tournamentId) 
        returns (address[] memory) 
    {
        return participantsList[_tournamentId];
    }
    
    /**
     * @dev Get player info
     */
    function getPlayerInfo(address _player) 
        external 
        view 
        returns (uint256, uint256, uint256, bool) 
    {
        Player memory player = players[_player];
        return (
            player.totalTournamentsPlayed,
            player.totalWinnings,
            player.skillRating,
            player.isRegistered
        );
    }
    
    /**
     * @dev Get tournament info
     */
    function getTournamentInfo(uint256 _tournamentId) 
        external 
        view 
        validTournament(_tournamentId) 
        returns (
            string memory name,
            address organizer,
            uint256 entryFee,
            uint256 prizePool,
            uint256 maxParticipants,
            uint256 currentParticipants,
            bool isActive,
            bool isCompleted,
            address winner
        ) 
    {
        Tournament memory t = tournaments[_tournamentId];
        return (
            t.name,
            t.organizer,
            t.entryFee,
            t.prizePool,
            t.maxParticipants,
            t.currentParticipants,
            t.isActive,
            t.isCompleted,
            t.winner
        );
    }
    
    /**
     * @dev Owner functions
     */
    function pauseTournament(uint256 _tournamentId) external onlyOwner validTournament(_tournamentId) {
        tournaments[_tournamentId].isActive = false;
    }
    
    function unpauseTournament(uint256 _tournamentId) external onlyOwner validTournament(_tournamentId) {
        tournaments[_tournamentId].isActive = true;
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
