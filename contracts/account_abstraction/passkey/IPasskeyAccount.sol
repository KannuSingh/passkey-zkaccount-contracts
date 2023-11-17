// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface IPasskeyAccount {
    struct Passkey {
        bytes32 id;
        uint256 pubKeyX;
        uint256 pubKeyY;
    }

    struct PasskeySigData {
        uint256 challengeLocation;
        uint256 responseTypeLocation;
        uint256 r;
        uint256 s;
        bool requireUserVerification;
        bytes authenticatorData;
        string clientDataJSON;
    }
}
