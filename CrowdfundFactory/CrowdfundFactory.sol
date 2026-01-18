// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CrowdfundProposal.sol";
import "./ParticipationSBT.sol";

/**
 * @title CrowdfundFactory
 * @author 0xnigromante
 * @notice Factory contract for creating crowdfunding campaigns with associated Participation SBTs
 * @dev This contract handles the deployment of both CrowdfundProposal and ParticipationSBT contracts
 *      in a single transaction, establishing the relationship between them
 */
contract CrowdfundFactory {
    /// @notice Emitted when a new crowdfunding campaign is successfully created
    /// @param proposalAddr Address of the newly deployed CrowdfundProposal contract
    /// @param sbtAddr Address of the newly deployed ParticipationSBT contract
    /// @param creator Address of the campaign creator (message sender)
    event NewProposal(address proposalAddr, address sbtAddr, address creator);

    /**
     * @notice Creates a new crowdfunding campaign with its associated Participation SBT
     * @dev Deploys both contracts and establishes their bidirectional relationship
     * @param _proposalCID IPFS CID containing the campaign metadata
     * @param _sbtMetadataURI Base URI for the Soulbound Token metadata
     * @param _sbtName Name of the Soulbound Token
     * @param _sbtSymbol Symbol for the Soulbound Token
     * @param _target Funding target amount in wei
     * @param _min Minimum contribution amount in wei
     * @param _duration Campaign duration in seconds
     * @param _refundable Flag indicating whether contributions are refundable if target isn't met
     * @return Address of the deployed CrowdfundProposal contract
     * @return Address of the deployed ParticipationSBT contract
     */
    function deployCampaign(
        string memory _proposalCID,
        string memory _sbtMetadataURI,
        string memory _sbtName,
        string memory _sbtSymbol,
        uint256 _target,
        uint256 _min,
        uint256 _duration,
        bool _refundable
    ) external returns (address, address) {

        // 1. Desplegar Propuesta
        CrowdfundProposal proposal = new CrowdfundProposal(
            msg.sender, _proposalCID, _target, _min, _duration, _refundable
        );

        // 2. Desplegar SBT pasando la dirección de la propuesta como Owner
        ParticipationSBT sbt = new ParticipationSBT(
            _sbtName, _sbtSymbol, _sbtMetadataURI, address(proposal)
        );

        // 3. Vincular SBT en la Propuesta
        proposal.setSBT(address(sbt));

        emit NewProposal(address(proposal), address(sbt), msg.sender);
        return (address(proposal), address(sbt));
    }
}