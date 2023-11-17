// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface IPaymasterMetadata {
    /// @notice A metadataCID of this paymaster contract
    function metadataCID() external view returns (bytes memory _cid);

    /// @dev This event emits when the metadata of a paymaster is changed.
    /// So that the third-party platforms such as paymaster market could
    /// timely update the metadata and related attributes of the paymaster.
    event MetadataUpdate(bytes _cid);
}

// {
//     "title": "Paymaster Metadata",
//     "type": "object",
//     "properties": {
//         "name": {
//             "type": "string",
//             "description": "Identifies the paymaster it represents"
//         },
//         "description": {
//             "type": "string",
//             "description": "Describes the paymaster it represents"
//         },
//         "image": {
//             "type": "string",
//             "description": "A URI pointing to a resource with mime type image/* representing the paymaster. Consider making any images at a width between 320 and 1080 pixels and aspect ratio between 1.91:1 and 4:5 inclusive."
//         },
//         "offchain_service_url": {
//             "type": "string",
//             "description": "A URL pointing to a offchain paymaster service ."
//         }
//     }
// }
