// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./callback/TokenCallbackHandler.sol";
import "../core/BaseAccount.sol";
import "../interfaces/IZkSessionAccountVerifier.sol";
import "../WebauthnLibs/WebAuthn.sol";
import "../passkey/IPasskeyAccount.sol";

/**
 * minimal account.
 *  this is sample minimal account.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract PasskeyZkAccount is
    BaseAccount,
    TokenCallbackHandler,
    UUPSUpgradeable,
    Initializable,
    IPasskeyAccount
{
    struct ZkSession {
        uint256 sessionCommitment;
        // The UNIX timestamp (seconds) when the permission is not valid anymore (0 = infinite)
        uint48 validUntil;
        // The UNIX timestamp when the permission becomes valid
        uint48 validAfter;
    }

    // Define a struct to match the SessionProof structure
    struct SessionSignatureProof {
        address application;
        uint256 nullifierHash;
        uint256[8] values; // Assuming there are 8 values in the SessionProof
    }

    using ECDSA for bytes32;

    Passkey public _signer;
    IEntryPoint private immutable _entryPoint;
    IZkSessionAccountVerifier private immutable _sessionVerifier;

    mapping(address => ZkSession) private _applicationSession;

    event PasskeyZkAccountInitialized(
        IEntryPoint indexed entryPoint,
        Passkey indexed signer
    );

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(
        IEntryPoint anEntryPoint,
        IZkSessionAccountVerifier sessionVerifier
    ) {
        _entryPoint = anEntryPoint;
        _sessionVerifier = sessionVerifier;
        _disableInitializers();
    }

    function _onlyOwner() internal view {
        // through the account itself (which gets redirected through execute())
        require(msg.sender == address(this), "only owner");
    }

    /**
     * get session commitment for the dapp which user want to use
     */
    function getSessionForApplication(
        address applicationContractAddress
    ) public view returns (ZkSession memory) {
        return _applicationSession[applicationContractAddress];
    }

    /**
     * set session commitment for the dapp which user want to use
     */
    function setSessionForApplication(
        address applicationContractAddress,
        ZkSession calldata session
    ) public {
        _requireFromEntryPoint();
        _applicationSession[applicationContractAddress] = session;
    }

    // Require the function call went through EntryPoint or owner
    function _requireValidSessionProof(
        uint256[8] memory sessionProof,
        uint256[3] memory proofInput
    ) internal view returns (bool) {
        return
            _sessionVerifier.verifyProof(
                [sessionProof[0], sessionProof[1]],
                [
                    [sessionProof[2], sessionProof[3]],
                    [sessionProof[4], sessionProof[5]]
                ],
                [sessionProof[6], sessionProof[7]],
                proofInput
            );
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPoint();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external {
        _requireFromEntryPoint();
        require(
            dest.length == func.length &&
                (value.length == 0 || value.length == func.length),
            "wrong array lengths"
        );
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(
        bytes32 id,
        uint256 pubKeyX,
        uint256 pubKeyY
    ) public virtual initializer {
        _initialize(id, pubKeyX, pubKeyY);
    }

    function _initialize(
        bytes32 id,
        uint256 pubKeyX,
        uint256 pubKeyY
    ) internal virtual {
        _signer = Passkey(id, pubKeyX, pubKeyY);
        emit PasskeyZkAccountInitialized(_entryPoint, _signer);
    }

    // // Require the function call went through EntryPoint or owner
    // function _requireFromEntryPointOrOwner() internal view {
    //     require(
    //         msg.sender == address(entryPoint()) || msg.sender == owner,
    //         "account: not Owner or EntryPoint"
    //     );
    // }

    // no-op function with structs as arguments to expose it in generated ABI
    // for client-side usage
    function passkeySignatureStruct(PasskeySigData memory sig) public {}

    // no-op function with structs as arguments to expose it in generated ABI
    // for client-side usage
    function sessionSignatureProofStruct(
        SessionSignatureProof memory sig
    ) public {}

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        // Decode the userOp.signature
        bytes4 mode = bytes4(userOp.signature[:4]);
        if (mode == bytes4(0x00000001)) {
            SessionSignatureProof memory sessionProof = abi.decode(
                userOp.signature[32:],
                (SessionSignatureProof)
            );
            ZkSession memory session = _applicationSession[
                sessionProof.application
            ];
            require(
                session.sessionCommitment != 0,
                "No session set for this application"
            );

            uint256[3] memory proofInputs = [
                session.sessionCommitment,
                sessionProof.nullifierHash,
                uint256(userOpHash) >> uint256(8)
            ];
            if (!_requireValidSessionProof(sessionProof.values, proofInputs)) {
                return SIG_VALIDATION_FAILED;
            } else {
                return
                    (uint256(session.validUntil) << 160) |
                    (uint256(session.validAfter) << 208);
            }
        } else if (mode == bytes4(0x00000000)) {
            PasskeySigData memory passkeyData = abi.decode(
                userOp.signature[32:],
                (PasskeySigData)
            );
            bool result = WebAuthn.verifySignature(
                bytes.concat(userOpHash),
                passkeyData.authenticatorData,
                passkeyData.requireUserVerification,
                passkeyData.clientDataJSON,
                passkeyData.challengeLocation,
                passkeyData.responseTypeLocation,
                passkeyData.r,
                passkeyData.s,
                _signer.pubKeyX,
                _signer.pubKeyY
            );
            if (result) {
                return 0;
            }
        }
        return SIG_VALIDATION_FAILED;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }
}
