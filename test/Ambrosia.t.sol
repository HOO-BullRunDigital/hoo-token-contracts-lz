// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import {OFTMock} from "./mocks/OFTMock.sol";
import {AmbrosiaMock} from "./mocks/AmbrosiaMock.sol";
import { OApp } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

import {ICommonOFT} from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/interfaces/ICommonOFT.sol";

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import {OFT} from "../src/OFT.sol";
import {AmbrosiaV2} from "../src/AmbrosiaV2.sol";
import {UUPSProxy} from "../src/UUPSProxy.sol";
import {ProxyTestHelper} from "./utils/ProxyTestHelper.sol";

contract AmbrosiaTest is ProxyTestHelper {
    using OptionsBuilder for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;
    uint32 cEid = 3;

    OFTMock aOFT;
    OFTMock bOFT;

    AmbrosiaMock public ambrosiaOFT_A;
    AmbrosiaMock public ambrosiaOFT_B;

    address public userA = address(0x1);
    address public userB = address(0x2);
    address public userC = address(0x3);
    uint256 public initialBalance = 100 ether;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.deal(userC, 1000 ether);

        super.setUp();

        setUpEndpoints(3, LibraryType.SimpleMessageLib);

        aOFT = OFTMock(
            _deployOAppProxyGeneralized(
                type(OFTMock).creationCode,
                abi.encodeWithSelector(OFT.initialize.selector, "aOFT", "aOFT", address(endpoints[aEid]), address(this))
            )
        );

        bOFT = OFTMock(
            _deployOAppProxyGeneralized(
                type(OFTMock).creationCode,
                abi.encodeWithSelector(OFT.initialize.selector, "bOFT", "bOFT", address(endpoints[bEid]), address(this))
            )
        );

        ambrosiaOFT_A = AmbrosiaMock(
            _deployOAppProxyGeneralized(
                type(AmbrosiaMock).creationCode,
                abi.encodeWithSelector(AmbrosiaV2.initialize.selector, "ambrosiaOFT_A", "ambrosiaOFT_A", address(endpoints[aEid]), address(this))
            )
        );

        ambrosiaOFT_B = AmbrosiaMock(
            _deployOAppProxyGeneralized(
                type(AmbrosiaMock).creationCode,
                abi.encodeWithSelector(AmbrosiaV2.initialize.selector, "ambrosiaOFT_B", "ambrosiaOFT_B", address(endpoints[bEid]), address(this))
            )
        );

        address[] memory admins = new address[](1);
        admins[0] = address(this);


        // config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(aOFT);
        ofts[1] = address(bOFT);
        this.wireOApps(ofts);

        // config and wire the ambrosias
        address[] memory ambrosias = new address[](2);
        ambrosias[0] = address(ambrosiaOFT_A);
        ambrosias[1] = address(ambrosiaOFT_B);
        this.wireOApps(ambrosias);




        // mint ambrosia tokens
        ambrosiaOFT_A.mint(userA, initialBalance);
        ambrosiaOFT_B.mint(userB, initialBalance);

        // mint tokens
        aOFT.mint(userA, initialBalance);
        bOFT.mint(userB, initialBalance);
    }

    function test_initializer() public {
        assertEq(aOFT.owner(), address(this));
        assertEq(bOFT.owner(), address(this));

        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(bOFT.balanceOf(userB), initialBalance);

        assertEq(aOFT.token(), address(aOFT));
        assertEq(bOFT.token(), address(bOFT));
    }

    function test_send_ambrosia_oft() public {
        uint256 tokensToSend = 1 ether;
        SendParam memory sendParam = SendParam(bEid, addressToBytes32(userB), tokensToSend, tokensToSend);
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        MessagingFee memory fee = ambrosiaOFT_A.quoteSend(sendParam, options, false, "", "");
        console2.log("Native Fee is : ", fee.nativeFee, "\n");
        console2.log("lzToken Fee is : ", fee.lzTokenFee, "\n");
        assertEq(ambrosiaOFT_A.balanceOf(userA), initialBalance);
        assertEq(ambrosiaOFT_B.balanceOf(userB), initialBalance);

        vm.prank(userA);
        ambrosiaOFT_A.send{value: fee.nativeFee}(sendParam, options, fee, payable(address(this)), "", "");
        verifyPackets(bEid, addressToBytes32(address(ambrosiaOFT_B)));

        assertEq(ambrosiaOFT_A.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(ambrosiaOFT_B.balanceOf(userB), initialBalance + tokensToSend);
    }

    function test_send_oft() public {
        uint256 tokensToSend = 1 ether;
        SendParam memory sendParam = SendParam(bEid, addressToBytes32(userB), tokensToSend, tokensToSend);
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        MessagingFee memory fee = aOFT.quoteSend(sendParam, options, false, "", "");
        console2.log("Native Fee is : ", fee.nativeFee, "\n");
        console2.log("lzToken Fee is : ", fee.lzTokenFee, "\n");
        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(bOFT.balanceOf(userB), initialBalance);

        vm.prank(userA);
        aOFT.send{value: fee.nativeFee}(sendParam, options, fee, payable(address(this)), "", "");
        verifyPackets(bEid, addressToBytes32(address(bOFT)));

        assertEq(aOFT.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bOFT.balanceOf(userB), initialBalance + tokensToSend);
    }

    function _deployOAppProxy(address _endpoint, address _owner, address implementationAddress)
    internal
    override
    returns (address proxyAddress)
    {}
}
