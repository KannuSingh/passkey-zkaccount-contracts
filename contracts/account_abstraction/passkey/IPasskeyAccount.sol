// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

interface IPasskeyAccount {
    struct Passkey {
        uint256 pubKeyX;
        uint256 pubKeyY;
        bytes credentialId;
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
