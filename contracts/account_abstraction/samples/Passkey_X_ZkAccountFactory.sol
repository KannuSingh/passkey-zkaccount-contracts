// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./Passkey_X_ZkAccount.sol";

/**
 * A sample factory contract for SimpleZkSessionAccount
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract PasskeyZkAccountFactory {
    PasskeyZkAccount public immutable accountImplementation;

    constructor(
        IEntryPoint _entryPoint,
        IZkSessionAccountVerifier _sessionVerifier
    ) {
        accountImplementation = new PasskeyZkAccount(
            _entryPoint,
            _sessionVerifier
        );
    }

    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(
        bytes32 id,
        uint256 pubKeyX,
        uint256 pubKeyY,
        uint salt
    ) public returns (PasskeyZkAccount ret) {
        address addr = getCounterfactualAddress(id, pubKeyX, pubKeyY, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return PasskeyZkAccount(payable(addr));
        }
        ret = PasskeyZkAccount(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(
                        PasskeyZkAccount.initialize,
                        (id, pubKeyX, pubKeyY)
                    )
                )
            )
        );
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getCounterfactualAddress(
        bytes32 id,
        uint256 pubKeyX,
        uint256 pubKeyY,
        uint salt
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(accountImplementation),
                            abi.encodeCall(
                                PasskeyZkAccount.initialize,
                                (id, pubKeyX, pubKeyY)
                            )
                        )
                    )
                )
            );
    }
}
