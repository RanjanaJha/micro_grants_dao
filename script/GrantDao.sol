// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

contract GrantDao {

    /**
     * @notice Structure to represent a grant proposal
     */
    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 budget;
        address proposer;
        uint256 likes;
        uint256 dislikes;
        Status status;
        uint256 startTime;
        uint256 endTime;
    }

    enum Status { Pending, Approved, Rejected }

    Proposal[] public proposals;
    address public owner;
    uint256 public treasuryBalance;
    uint256 public votingDuration;
    mapping(uint256 => mapping(address => bool)) public votes;


    constructor() {
        owner = msg.sender;
        votingDuration = 5 minutes;
    }

    event NewProposal(uint256 id, string title, address proposer);
    event VoteCast(uint256 proposalId, address voter, bool support);
    event ProposalFinalized(uint256 proposalId, Status status);
    event TreasuryDeposited(uint256 amount);
    event FundDisbursed(uint256 proposalId, uint256 amount, address recipient);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    /**
     * @notice Submit a new grant proposal
     * @param _title The title of the proposal
     * @param _description The description of the proposal
     * @param _budget The requested budget for the proposal
     */
    function submitProposal(string memory _title, string memory _description, uint256 _budget) public returns (uint256) {
        uint256 index = proposals.length;
        Proposal memory newProposal = Proposal({
            id: index,
            title: _title,
            description: _description,
            budget: _budget,
            proposer: msg.sender,
            status: Status.Pending,
            likes: 0,
            dislikes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingDuration
        });
        proposals.push(newProposal);
        emit NewProposal(index, newProposal.title, msg.sender);
        return index;
    }

    /**
     * @notice Get the total number of proposals
     */
    function getProposalCount() public view returns (uint256) {
        return proposals.length;
    }

    /**
     * @notice Get details of a specific proposal
     * @param _id The ID of the proposal
     */
    function getProposal(uint256 _id) public view returns (uint256, string memory, string memory, uint256, address, uint256, uint256, Status) {
        Proposal storage proposal = proposals[_id];
        return (proposal.id, proposal.title, proposal.description, proposal.budget, proposal.proposer, proposal.likes, proposal.dislikes, proposal.status);
    }

    /**
     * @notice Get all proposals
     */
    function getAllProposals() public view returns (Proposal[] memory) {
        return proposals;
    }

    /**
     * @notice Vote on a proposal
     * @param _id The ID of the proposal
     * @param _support True to like, false to dislike
     */
    function vote(uint256 _id, bool _support) public {
        require(block.timestamp < proposals[_id].endTime, "Voting period ended");
        Proposal storage proposal = proposals[_id];
        require(proposal.status == Status.Pending, "Proposal is not pending");
        require(!votes[_id][msg.sender], "You have already voted");

        votes[_id][msg.sender] = true;

        emit VoteCast(_id, msg.sender, _support);

        if (_support) {
            proposal.likes++;
        } else {
            proposal.dislikes++;
        }
    }

    /**
     * @notice Deposit funds into the treasury
     */
    function depositTreasury() public payable {
        require(msg.sender == owner, "Only owner can deposit");
        treasuryBalance += msg.value;
    }

    /**
     * @notice End voting on a proposal and finalize its status
     * @param _id The ID of the proposal
     */
    function endVoting(uint256 _id) public {
        Proposal storage proposal = proposals[_id];
        require(block.timestamp >= proposal.endTime, "Voting period not ended");
        require(proposal.status == Status.Pending, "Proposal already finalized");

        if (proposal.likes > proposal.dislikes) {
            proposal.status = Status.Approved;
           
        } else {
            proposal.status = Status.Rejected;
        }

        emit ProposalFinalized(_id, proposal.status);
    }

    /**
     * @notice Execute an approved proposal and transfer funds
     * @param _id The ID of the proposal
     */
    function executeProposal(uint256 _id) public onlyOwner {
        Proposal storage proposal = proposals[_id];
        require(proposal.status == Status.Approved, "Proposal not approved");
        require(treasuryBalance >= proposal.budget, "Insufficient treasury funds");
        treasuryBalance -= proposal.budget;
        (bool success,) = payable(proposal.proposer).call{value: proposal.budget}("");
        require(success,"Trasnfer Failed.");
        emit FundDisbursed(_id, proposal.budget, proposal.proposer);
    }


}