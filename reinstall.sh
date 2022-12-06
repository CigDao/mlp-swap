#!/bin/bash

dfx canister --network ic install swap --argument='(principal "wzcbw-cyaaa-aaaag-qbbca-cai", principal "7bhjd-tqaaa-aaaan-qbv6q-cai",)' --mode reinstall

dfx canister --network ic install token1 --argument='("","Token 1","T1",8,100000000000000000000,principal "j26ec-ix7zw-kiwcx-ixw6w-72irq-zsbyr-4t7fk-alils-u33an-kh6rk-7qe", 0,)' --mode reinstall 
dfx canister --network ic install token2 --argument='("","Token 2","T2",8,100000000000000000000,principal "j26ec-ix7zw-kiwcx-ixw6w-72irq-zsbyr-4t7fk-alils-u33an-kh6rk-7qe", 0,)' --mode reinstall    
