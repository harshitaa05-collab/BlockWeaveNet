// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BlockWeaveNet
 * @dev Lightweight content graph: nodes with labeled links (edges) between them
 * @notice Register nodes by hash/id and create directional links to weave a network
 */
contract BlockWeaveNet {
    address public owner;

    struct Node {
        bytes32 id;          // logical node id (e.g. content hash, UUID)
        address creator;
        string  label;       // human-readable label
        string  uri;         // optional off-chain reference
        uint256 createdAt;
        bool    isActive;
    }

    struct Link {
        bytes32 fromId;
        bytes32 toId;
        string  relation;    // e.g. "references", "derived-from", "duplicate-of"
        uint256 createdAt;
        bool    isActive;
    }

    // nodeId => Node
    mapping(bytes32 => Node) public nodes;

    // nodeId => outgoing links
    mapping(bytes32 => Link[]) public outgoingLinks;

    // nodeId => incoming links
    mapping(bytes32 => Link[]) public incomingLinks;

    // creator => nodeIds
    mapping(address => bytes32[]) public nodesOf;

    event NodeRegistered(
        bytes32 indexed id,
        address indexed creator,
        string label,
        string uri,
        uint256 createdAt
    );

    event NodeStatusUpdated(
        bytes32 indexed id,
        bool isActive,
        uint256 timestamp
    );

    event LinkCreated(
        bytes32 indexed fromId,
        bytes32 indexed toId,
        string relation,
        uint256 createdAt
    );

    event LinkStatusUpdated(
        bytes32 indexed fromId,
        bytes32 indexed toId,
        string relation,
        bool isActive,
        uint256 timestamp
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier nodeExists(bytes32 id) {
        require(nodes[id].creator != address(0), "Node not found");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Register a new node in the weave
     * @param id Logical identifier of the node
     * @param label Human-readable label
     * @param uri Optional off-chain reference
     */
    function registerNode(
        bytes32 id,
        string calldata label,
        string calldata uri
    ) external {
        require(id != 0, "Invalid id");
        require(nodes[id].creator == address(0), "Node exists");

        nodes[id] = Node({
            id: id,
            creator: msg.sender,
            label: label,
            uri: uri,
            createdAt: block.timestamp,
            isActive: true
        });

        nodesOf[msg.sender].push(id);

        emit NodeRegistered(id, msg.sender, label, uri, block.timestamp);
    }

    /**
     * @dev Toggle node active status
     * @param id Node identifier
     * @param active New active state
     */
    function setNodeActive(bytes32 id, bool active)
        external
        nodeExists(id)
    {
        require(nodes[id].creator == msg.sender || msg.sender == owner, "Not authorized");
        nodes[id].isActive = active;
        emit NodeStatusUpdated(id, active, block.timestamp);
    }

    /**
     * @dev Create a directional link between two nodes
     * @param fromId Source node id
     * @param toId Target node id
     * @param relation Relationship label
     */
    function createLink(
        bytes32 fromId,
        bytes32 toId,
        string calldata relation
    )
        external
        nodeExists(fromId)
        nodeExists(toId)
    {
        require(nodes[fromId].creator == msg.sender || msg.sender == owner, "Not authorized");

        Link memory link = Link({
            fromId: fromId,
            toId: toId,
            relation: relation,
            createdAt: block.timestamp,
            isActive: true
        });

        outgoingLinks[fromId].push(link);
        incomingLinks[toId].push(link);

        emit LinkCreated(fromId, toId, relation, block.timestamp);
    }

    /**
     * @dev Deactivate or reactivate a link (by index in outgoing list)
     * @param fromId Source node id
     * @param index Index in outgoingLinks[fromId] array
     * @param active New active state
     */
    function setLinkActive(
        bytes32 fromId,
        uint256 index,
        bool active
    )
        external
        nodeExists(fromId)
    {
        require(nodes[fromId].creator == msg.sender || msg.sender == owner, "Not authorized");
        require(index < outgoingLinks[fromId].length, "Invalid index");

        Link storage linkOut = outgoingLinks[fromId][index];
        linkOut.isActive = active;

        // Mirror change in incomingLinks for the target node
        bytes32 toId = linkOut.toId;
        Link[] storage inArr = incomingLinks[toId];
        for (uint256 i = 0; i < inArr.length; i++) {
            if (
                inArr[i].fromId == fromId &&
                keccak256(bytes(inArr[i].relation)) == keccak256(bytes(linkOut.relation)) &&
                inArr[i].createdAt == linkOut.createdAt
            ) {
                inArr[i].isActive = active;
                break;
            }
        }

        emit LinkStatusUpdated(fromId, toId, linkOut.relation, active, block.timestamp);
    }

    /**
     * @dev Get all node ids created by a user
     */
    function getNodesOf(address user) external view returns (bytes32[] memory) {
        return nodesOf[user];
    }

    /**
     * @dev Get outgoing links for a node
     */
    function getOutgoingLinks(bytes32 id)
        external
        view
        nodeExists(id)
        returns (Link[] memory)
    {
        return outgoingLinks[id];
    }

    /**
     * @dev Get incoming links for a node
     */
    function getIncomingLinks(bytes32 id)
        external
        view
        nodeExists(id)
        returns (Link[] memory)
    {
        return incomingLinks[id];
    }

    /**
     * @dev Transfer contract ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
