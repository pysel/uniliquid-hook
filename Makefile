include .env

deploy-mock-tokens:
	forge script script/mocks/MockER20.s.sol:MockTokenScript --rpc-url $(RPC_URL) --chain-id $(CHAIN_ID) --mnemonics $(MNEMONIC) --broadcast --sender $(SENDER)

deploy-hook:
	forge script script/00_Uniliquid.s.sol:UniliquidHookScript --rpc-url $(RPC_URL) --chain-id $(CHAIN_ID) --mnemonics $(MNEMONIC) --broadcast --sender $(SENDER)

deploy-pool-with-initial-liquidity:
	forge script script/01_CreatePoolAndMintLiquidity.s.sol:CreatePoolAndMintLiquidityScript --rpc-url $(RPC_URL) --chain-id $(CHAIN_ID) --mnemonics $(MNEMONIC) --broadcast --sender $(SENDER)

deploy-all:
	deploy-hook
	deploy-mock-tokens
	deploy-pool-with-initial-liquidity

swap:
	forge script script/02_Swap.s.sol:SwapScript --rpc-url $(RPC_URL) --chain-id $(CHAIN_ID) --mnemonics $(MNEMONIC) --broadcast --sender $(SENDER)

fund-me:
	forge script script/testnet/FundERC20.s.sol:FundERC20Script --rpc-url $(RPC_URL) --chain-id $(CHAIN_ID) --mnemonics $(MNEMONIC) --broadcast --sender $(SENDER)

add-liquidity:
	forge script script/02_AddLiquidity.s.sol:AddLiquidityScript --rpc-url $(RPC_URL) --chain-id $(CHAIN_ID) --mnemonics $(MNEMONIC) --broadcast --sender $(SENDER)