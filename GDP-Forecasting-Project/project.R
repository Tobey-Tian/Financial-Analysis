---
title: "China's GDP Forecasting Project"
author: "Yuan Tian"
date: "4/12/2020"
output:
  word_document: default
  html_document: default
---

```{r,warning=FALSE, message=FALSE}
library(forecast)
library(ggplot2)
library(urca)
```

## Part 1. Data description

# 1.1 Load and prepare data

I choose the data of China's quartely GDP from 1992 to 2019(Chinese currency) from the website of Federal Reserve Economic Data repository (FRED), the original [data](https://fred.stlouisfed.org/series/CHNGDPNQDSMEI) is in Chinese currency without seasonal adjustion. 

```{r,warning=FALSE, message=FALSE}
gdp.data <- read.csv("CHNGDPNQDSMEI.csv")
colnames(gdp.data)[2] <- "GDP"
head(gdp.data)
#convert to quarterly time series data
gdp.ts <- ts(gdp.data$GDP,start=c(1992,1),freq=4)
```

# 1.2 Data visualization

Time series plot
```{r,warning=FALSE, message=FALSE}
#Original gdp plot
plot(gdp.ts)
title('The quarterly China’s GDP Time series (1992:01-2019:04)')
grid()
# From the plot we see there is an obviously trend and some seasonality
```

## Part 2. Model Selection

# 2.1 Check trend 
```{r,warning=FALSE, message=FALSE}
# Fit linear trend
gdp.lin <- tslm(gdp.ts ~ trend)
# Fit exponential trend, lambda = 0 peforms log transform on data
gdp.exp <- tslm(gdp.ts ~ trend, lambda = 0)
# plot data and trends
plot(gdp.ts,ylab="China's quartely GDP ",xlab="Time",lwd=2)
lines(gdp.lin$fitted.values,col="blue",lwd=2)
lines(gdp.exp$fitted.values,col="red",lwd=2)
legend('topleft',c("GDP","Linear","Exponential"),col=c("black","blue","red"),lwd=c(2,2,2))
grid()
# From the plot, we can see the gdp data has an exponential trend, in this case, it needs log transformation
gdp.ts <- log(gdp.ts)
#log(gdp)plot
plot(gdp.ts)
title('The quarterly China’s log(GDP) Time series (1992:01-2019:04)')
grid()
```
# 2.2 Check stationarity

```{r,warning=FALSE, message=FALSE}
# We should ensure that the time series being analyzed is stationary before specifying a model.
# run adf test with the gdp data test
# The hypotheses are: tau:gamma=0 phi3:gamma = a2 = 0 phi2: a0 = gamma = a2 = 0 #
df.test<-ur.df(gdp.ts,type='trend',selectlags='BIC') 
sumstats <- summary(df.test)
sumstats
# run the type 3 test(with trend), in tau3, the teststat is -4.3846 and the 5% critical value is -3.43, wo we can reject the null to rule out an unit root. And since 14.9132>4.75 and 10.3163>6.49, we can reject the null under all the three assumptions. 
```

# 2.3 ACF and PACF plot
```{r,warning=FALSE, message=FALSE}
Acf(gdp.ts)
pacf(gdp.ts)
# From the acf plot, there are diminishing spikes last until 20, which means a MA(∞),and since the stikes at 4,8,12 are siginificant, it has seasonal effects
# From the pacf plot, the significant spike at lag 1 suggests a non-seasonal AR(1) component,and since there are also some strikes every 4 time periods, it may also has some seasonal effects. 
```

# 2.4 Check seasonality
```{r,warning=FALSE, message=FALSE}
# From the plot, we see some seasonal effects, so check the trend and seasonality
gdp.lin.season <- tslm(gdp.ts~trend+season)
summary(gdp.lin.season)
# The results shows significantly trend and seasonal components.although the adf test shows there is no unit root,there can still be a trend component in the data
# First, fit the ARMA(1,0,0) (0,1,0)[4] model with xreg equals trend
T <- length(gdp.ts)
gdp.fit <- Arima(gdp.ts,order=c(1,0,0),seasonal=c(0,1,0),xreg=(1:T))
summary(gdp.fit)
# Then run auto arima to check the model
gdp.mod <- auto.arima(gdp.ts)
summary(gdp.mod)
# The auto arima model uses first differencing to capture the trend, but the BIC and RMSE are both smaller than my initial model, so finally decide to choose auto arima model, which is ARIMA(1,1,0) (0,1,0)[4]model
```

# 2.4 Final model
Based on the trend and seasonal analysis, and the AR(1) component from pacf plot, I decided to run the ARIMA(1,1,0) (0,1,0)[4]model on the log(gdp) data. The function is:
```{r,warning=FALSE, message=FALSE}
# length of full data set
fit <- Arima(gdp.ts, order=c(1,1,0), seasonal=c(0,1,0))
summary(fit)
# Then, check the residuals
checkresiduals(fit)
# The residual plot shows no autocorrelations and the histogram is bell shaped,so the model passes the required checks
```
The final model equation is: Log(GDP)(t)=0.4685Log(GDP)(t-1)+Log(GDP)(t-12)-0.4685Log(GDP)(t-13)+e(t)

## Part 3.Forecasting

# 3.1 Split data
```{r,warning=FALSE, message=FALSE}
# Set training and validation data set
gdp.train.ts <- window( gdp.ts, start=c(1992,1),end=c(2011,4))
gdp.valid.ts <- window( gdp.ts, start=c(2012,1))
# length of valid data set
nvalid <- length(gdp.valid.ts)
```

# 3.2 Forecasting on the model
```{r,warning=FALSE, message=FALSE}
train.mod <- Arima(gdp.train.ts, order=c(1,1,0), seasonal=c(0,1,0))
pred.mod <- forecast(train.mod,h=nvalid,level=95)
accuracy(pred.mod,gdp.valid.ts)

# plot the forecasting result
plot(pred.mod, ylab="China's log(GDP)",xlab="Time",bty="l", xaxt="n", xlim=c(1995,2020),main="", flty=2)
axis(1,at=seq(1995,2020,5),labels=format(seq(1995,2020,5)))
lines(gdp.valid.ts)
title('Forecasting of China GDP')
grid()
```

# 3.3 Compare the model
```{r,warning=FALSE, message=FALSE}
# run the train and test with baseline model
naiveValid <- meanf(gdp.train.ts,h=nvalid)
accuracy(naiveValid)
# dm test in train data
dm.test(train.mod$residuals,(gdp.train.ts-naiveValid$fitted),alternative="less")
# p-value is almost 0, can reject the null, my final model is better
# dm test in valid
dm.test(pred.mod$residuals,(gdp.valid.ts-naiveValid$mean),  alternative="less")
# p-value is almost 0, can reject the null, my final model is better

# My model is significantly better than the baseline model
```
