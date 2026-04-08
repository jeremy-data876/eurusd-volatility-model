install.packages("alphavantager") # Connects R to Alpha Vantage data
install.packages("tidyverse")     # The "gold standard" for data cleaning and plots
install.packages("tidyquant")     # Specialized for financial time-series
install.packages("rugarch")       # The engine for our GARCH volatility models

# Load the necessary libraries
library(alphavantager)
library(tidyverse)
library(tidyquant)

# Set your API Key (Replace with the one you got from Alpha Vantage)
av_api_key("AQ0BOZENGFIV6CEM")

# Fetch Daily EUR/USD Data
# 'FX_DAILY' provides open, high, low, close for currency pairs
eur_usd_raw <- av_get(symbol = "EUR/USD", av_fun = "FX_DAILY", outputsize = "full")

# Inspect the first few rows
head(eur_usd_raw)

# Calculate Daily Log Returns
eur_usd_returns <- eur_usd_raw %>%
  arrange(timestamp) %>%
  mutate(log_return = log(close / lag(close)) * 100) %>%
  drop_na() # Remove the first row which will be NA

# Quick Plot to see Volatility Clustering
ggplot(eur_usd_returns, aes(x = timestamp, y = log_return)) +
  geom_line(color = "steelblue") +
  theme_minimal() +
  labs(title = "Daily Log Returns of EUR/USD", 
       y = "Log Return (%)", x = "Date")

# Histogram of Returns vs. Normal Distribution
ggplot(eur_usd_returns, aes(x = log_return)) +
  geom_histogram(aes(y = ..density..), bins = 50, fill = "steelblue", alpha = 0.7) +
  stat_function(fun = dnorm, 
                args = list(mean = mean(eur_usd_returns$log_return), 
                            sd = sd(eur_usd_returns$log_return)), 
                color = "red", size = 1) +
  theme_minimal() +
  labs(title = "Distribution of EUR/USD Returns",
       subtitle = "Blue = Actual Returns | Red Line = Theoretical Normal Distribution")

# Test for ARCH effects using squared returns
Box.test(eur_usd_returns$log_return^2, lag = 10, type = "Ljung-Box")

library(rugarch)

# Define the model structure
spec <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(0, 0), include.mean = TRUE),
  distribution.model = "sstd" # Student-t to handle the fat tails you saw!
)

# Fit the model to your EUR/USD returns
garch_fit <- ugarchfit(spec = spec, data = eur_usd_returns$log_return)

# View the results
print(garch_fit)

# 1. Forecast the next 5 days of volatility
garch_forecast <- ugarchforecast(garch_fit, n.ahead = 5)

# 2. Extract and Plot the Conditional Volatility (Sigma)
# This shows how "risky" the market was over time
eur_usd_returns$sigma <- garch_fit@fit$sigma

ggplot(eur_usd_returns, aes(x = timestamp, y = sigma)) +
  geom_line(color = "darkred") +
  theme_minimal() +
  labs(title = "EUR/USD Conditional Volatility (GARCH 1,1)",
       subtitle = "Visualizing risk clustering in Forex markets",
       y = "Sigma (Predicted Volatility)", x = "Date")

# 3. Print the Forecasted Volatility for the next week
print(garch_forecast)

# Save the Volatility Plot
ggsave("eurusd_volatility_garch.png", width = 10, height = 6, dpi = 300)

# Save the Histogram (Run the histogram code first, then this)
ggsave("eurusd_return_distribution.png", width = 10, height = 6, dpi = 300)