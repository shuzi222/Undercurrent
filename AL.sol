// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AL1 {
    using SafeERC20 for IERC20;
    
    address public immutable developer;
    address public constant USDT_ADDRESS = 0x55d398326f99059fF775485246999027B3197955; // BSC USDT
    
    enum Platform { Bilibili, Douyin, Kuaishou }
    enum Type { Play, Like }
    enum PaymentToken { BNB, USDT }
    
    struct Order {
        address user;
        Platform platform;
        Type orderType;
        uint256 amount;
        PaymentToken paymentToken;
        uint256 payment;
        uint256 timestamp;
        string videoUrl; // 新增视频链接字段
    }
    
    // 环形缓冲区存储订单
    Order[100] public orders;
    uint256 public nextIndex = 0;
    uint256 public constant MAX_ORDERS = 100;
    
    event OrderCreated(uint256 indexed orderId, address indexed user);
    
    constructor() {
        developer = msg.sender;
    }
    
    // 核心订单创建函数（添加videoUrl参数）
    function createOrder(
        Platform platform,
        Type orderType,
        uint256 amount,
        PaymentToken paymentToken,
        string memory videoUrl // 新增视频链接参数
    ) external payable {
        // 1. 过滤明显恶意订单
        if (!_isValidOrder(platform, orderType, amount, paymentToken, videoUrl)) {
            revert("Invalid order parameters");
        }
        
        // 2. 计算支付金额
        uint256 payment = _calculatePayment(platform, orderType, amount, paymentToken);
        
        // 3. 处理支付
        _processPayment(paymentToken, payment);
        
        // 4. 保存有效订单（包含视频链接）
        _saveOrder(platform, orderType, amount, paymentToken, payment, videoUrl);
    }
    
    // 验证订单基本有效性（添加视频链接验证）
    function _isValidOrder(
        Platform platform,
        Type orderType,
        uint256 amount,
        PaymentToken paymentToken,
        string memory videoUrl
    ) private pure returns (bool) {
        // 检查视频链接非空
        if (bytes(videoUrl).length == 0) {
            return false;
        }
        
        // 点赞订单必须使用BNB
        if (orderType == Type.Like && paymentToken != PaymentToken.BNB) {
            return false;
        }
        
        // 检查数量是否符合基本单位
        if (platform == Platform.Bilibili) {
            if (orderType == Type.Play) return amount % 1000 == 0;
            else return amount % 10 == 0; // Like
        }
        else if (platform == Platform.Douyin) {
            if (orderType == Type.Play) return amount % 1000 == 0;
            else return amount % 10 == 0; // Like
        }
        else if (platform == Platform.Kuaishou) {
            if (orderType == Type.Play) return amount % 10000 == 0;
            else return amount % 10 == 0; // Like
        }
        
        return false;
    }
    
    // 计算支付金额（保持不变）
    function _calculatePayment(
        Platform platform,
        Type orderType,
        uint256 amount,
        PaymentToken paymentToken
    ) private pure returns (uint256) {
        if (platform == Platform.Bilibili) {
            if (orderType == Type.Play) {
                return (amount / 1000) * (paymentToken == PaymentToken.BNB ? 7e15 : 35e17);
            } else { // Like
                return (amount / 10) * 1e15;
            }
        }
        else if (platform == Platform.Douyin) {
            if (orderType == Type.Play) {
                return (amount / 1000) * (paymentToken == PaymentToken.BNB ? 75e14 : 35e17);
            } else { // Like
                return (amount / 10) * 2e15;
            }
        }
        else if (platform == Platform.Kuaishou) {
            if (orderType == Type.Play) {
                return (amount / 10000) * (paymentToken == PaymentToken.BNB ? 3e15 : 2e18);
            } else { // Like
                return (amount / 10) * 1e15;
            }
        }
        
        revert("Invalid platform or type");
    }
    
    // 处理支付（保持不变）
    function _processPayment(
        PaymentToken paymentToken,
        uint256 payment
    ) private {
        if (paymentToken == PaymentToken.BNB) {
            require(msg.value == payment, "Incorrect BNB amount");
            payable(developer).transfer(payment);
        } else {
            IERC20(USDT_ADDRESS).safeTransferFrom(msg.sender, developer, payment);
        }
    }
    
    // 保存有效订单（添加视频链接）
    function _saveOrder(
        Platform platform,
        Type orderType,
        uint256 amount,
        PaymentToken paymentToken,
        uint256 payment,
        string memory videoUrl // 新增视频链接参数
    ) private {
        orders[nextIndex] = Order({
            user: msg.sender,
            platform: platform,
            orderType: orderType,
            amount: amount,
            paymentToken: paymentToken,
            payment: payment,
            timestamp: block.timestamp,
            videoUrl: videoUrl // 存储视频链接
        });
        
        nextIndex = (nextIndex + 1) % MAX_ORDERS;
        emit OrderCreated(nextIndex, msg.sender);
    }
    
    // 获取所有订单（保持不变）
    function getAllOrders() external view returns (Order[] memory) {
        Order[] memory allOrders = new Order[](MAX_ORDERS);
        for (uint256 i = 0; i < MAX_ORDERS; i++) {
            allOrders[i] = orders[i];
        }
        return allOrders;
    }
}