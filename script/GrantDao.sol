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
     * @param title The title of the proposal
     * @param description The description of the proposal
     * @param budget The requested budget for the proposal
     */
    function submitProposal(string memory title, string memory description, uint256 budget) public returns (uint256) {
        uint256 index = proposals.length;
        Proposal memory newProposal = Proposal({
            id: index,
            title: title,
            description: description,
            budget: budget,
            proposer: msg.sender,
            status: Status.Pending,
            likes: 0,
            dislikes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingDuration
        });
        proposals.push(newProposal);
        emit NewProposal(index, title, msg.sender);
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
     * @param id The ID of the proposal
     */
    function getProposal(uint256 id) public view returns (uint256, string memory, string memory, uint256, address, uint256, uint256, Status) {
        Proposal storage proposal = proposals[id];
        return (proposal.id,proposal.title, proposal.description, proposal.budget, proposal.proposer, proposal.likes, proposal.dislikes, proposal.status);
    }

    /**
     * @notice Get all proposals
     */
    function getAllProposals() public view returns (Proposal[] memory) {
        return proposals;
    }

    /**
     * @notice Vote on a proposal
     * @param id The ID of the proposal
     * @param support True to like, false to dislike
     */
    function vote(uint256 id, bool support) public {
        require(block.timestamp < proposals[id].endTime, "Voting period ended");
        Proposal storage proposal = proposals[id];
        require(proposal.status == Status.Pending, "Proposal is not pending");
        require(!votes[id][msg.sender], "You have already voted");

        votes[id][msg.sender] = true;

        emit VoteCast(id, msg.sender, support);

        if (support) {
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
     * @param id The ID of the proposal
     */
    function endVoting(uint256 id) public {
        Proposal storage proposal = proposals[id];
        require(block.timestamp >= proposal.endTime, "Voting period not ended");
        require(proposal.status == Status.Pending, "Proposal already finalized");

        if (proposal.likes > proposal.dislikes) {
            proposal.status = Status.Approved;
           
        } else {
            proposal.status = Status.Rejected;
        }

        emit ProposalFinalized(id, proposal.status);
    }

    /**
     * @notice Execute an approved proposal and transfer funds
     * @param id The ID of the proposal
     */
    function executeProposal(uint256 id) public onlyOwner {
        Proposal storage proposal = proposals[id];
        require(proposal.status == Status.Approved, "Proposal not approved");
        require(treasuryBalance >= proposal.budget, "Insufficient treasury funds");
        treasuryBalance -= proposal.budget;
        payable(proposal.proposer).transfer(proposal.budget);
        emit FundDisbursed(id, proposal.budget, proposal.proposer);
    }


}