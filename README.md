# Cross chain rebase token

1. A protocol that allows users to deposit into a vault and receive a rebase token that represents that represents their underlying balance

2. Rebase token balanceOf function is dynamic to show the changing balance with time
    - Balance increases linearly with time
    - mint tokens to users everytime they perform an action 

3. Interest
    - Individually set the interest rate of each user based on some global interest rate of the protocol at the time of deposit
    - The global interest rate can only decrease with time to incentivize/reward early adopters
