//+------------------------------------------------------------------+
//|    AdvancedTrendEA_MT5.mq5                                       |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputuri Strategie
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15; // Timeframe pentru indicatori
input ulong MagicNumber = 54321;         // Număr Magic unic pentru acest EA
input int FastMA_Period = 14;
input int SlowMA_Period = 50;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
input int RSI_Period = 14;
input double RSI_Buy_Level = 55;
input double RSI_Sell_Level = 45;

//--- Inputuri Managementul Banilor și Riscului
input double RiskPercent = 1.0;           // Procentul din cont riscat pe tranzacție
input int MaxOpenTrades = 5;               // Numărul maxim de tranzacții deschise simultan
input int ATR_Period = 14;                 // Perioada pentru ATR
input double ATR_StopLoss_Multiplier = 2.0; // Multiplicator ATR pentru Stop Loss
input double ATR_TakeProfit_Multiplier = 4.0;// Multiplicator ATR pentru Take Profit
input double ATR_MinVolatility_Pips = 5.0; // Volatilitate minimă (ATR în pips) pentru a tranzacționa

//--- Inputuri Trailing Stop
input double TrailingStart_Pips = 25.0;  // Când să înceapă trailing-ul, în pips
input double TrailingStop_Pips = 15.0;   // Distanța trailing stop-ului față de preț, în pips

//--- Handle indicatori
int handleFastMA, handleSlowMA, handleRSI, handleATR;

//--- Variabile globale
double _pipValue;   // Valoarea unui pip, calculată dinamic
bool isNewBar;      // Flag pentru bară nouă

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    if(_Digits == 3 || _Digits == 5) _pipValue = _Point * 10;
    else _pipValue = _Point;

    handleFastMA = iMA(_Symbol, Timeframe, FastMA_Period, 0, MA_Method, PRICE_CLOSE);
    handleSlowMA = iMA(_Symbol, Timeframe, SlowMA_Period, 0, MA_Method, PRICE_CLOSE);
    handleRSI    = iRSI(_Symbol, Timeframe, RSI_Period, PRICE_CLOSE);
    handleATR    = iATR(_Symbol, Timeframe, ATR_Period);

    if(handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE || handleRSI == INVALID_HANDLE || handleATR == INVALID_HANDLE)
    {
        Print("Eroare la crearea indicatorilor!");
        return(INIT_FAILED);
    }

    trade.SetExpertMagicNumber(MagicNumber);
    Print("Advanced Trend EA activ pe timeframe ", EnumToString(Timeframe));
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(handleFastMA);
    IndicatorRelease(handleSlowMA);
    IndicatorRelease(handleRSI);
    IndicatorRelease(handleATR);
    Print("EA a fost oprit. Resursele au fost eliberate.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    ManageTrailingStop();

    CheckForNewBar();
    if(!isNewBar) return;

    if(CountOpenTrades() >= MaxOpenTrades) return;

    double fastMA[2], slowMA[2], rsi[2], atr[2];
    if(!GetIndicatorValues(0, 2, fastMA, slowMA, rsi, atr)) return;

    double atr_pips = atr[1] / _pipValue;
    if(atr_pips < ATR_MinVolatility_Pips) return;

    double fastMA_recent = fastMA[1];
    double slowMA_recent = slowMA[1];
    double rsi_recent = rsi[1];

    // Logica de semnal bazată pe STARE pentru a permite piramidarea
    bool buySignal = fastMA_recent > slowMA_recent && rsi_recent > RSI_Buy_Level;
    bool sellSignal = fastMA_recent < slowMA_recent && rsi_recent < RSI_Sell_Level;

    if(buySignal) OpenPosition(ORDER_TYPE_BUY, atr[1]);
    if(sellSignal) OpenPosition(ORDER_TYPE_SELL, atr[1]);
}

//+------------------------------------------------------------------+
//| Verifică bară nouă                                               |
//+------------------------------------------------------------------+
void CheckForNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, Timeframe, SERIES_LASTBAR_DATE);
    if(lastBarTime < currentBarTime)
    {
        isNewBar = true;
        lastBarTime = currentBarTime;
    }
    else isNewBar = false;
}

//+------------------------------------------------------------------+
//| Numără tranzacțiile deschise de acest EA                         |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Obține valorile indicatorilor                                    |
//+------------------------------------------------------------------+
bool GetIndicatorValues(int start, int count, double &fastMA[], double &slowMA[], double &rsi[], double &atr[])
{
    if(CopyBuffer(handleFastMA, 0, start, count, fastMA) < count ||
       CopyBuffer(handleSlowMA, 0, start, count, slowMA) < count ||
       CopyBuffer(handleRSI, 0, start, count, rsi) < count ||
       CopyBuffer(handleATR, 0, start, count, atr) < count)
    {
        Print("Eroare la copierea datelor din indicatori!");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Calculează mărimea lotului pe baza riscului                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = accountBalance * (RiskPercent / 100.0);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(stopLossDistance <= 0 || tickValue <= 0) return 0.01;

    double lotSize = (riskAmount / stopLossDistance) * tickSize / tickValue;

    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    lotSize = floor(lotSize / lotStep) * lotStep;
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;

    return lotSize;
}


//+------------------------------------------------------------------+
//| Deschide o nouă poziție                                          |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType, double atrValue)
{
    double price, sl, tp;
    double sl_distance = atrValue * ATR_StopLoss_Multiplier;
    double tp_distance = atrValue * ATR_TakeProfit_Multiplier;

    double lotSize = CalculateLotSize(sl_distance);
    if(lotSize <= 0)
    {
        Print("Calculul lotului a eșuat. Lot size este zero.");
        return;
    }

    if(orderType == ORDER_TYPE_BUY)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = price - sl_distance;
        tp = price + tp_distance;
        trade.Buy(lotSize, _Symbol, price, sl, tp, "Buy opened by Advanced EA");
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = price + sl_distance;
        tp = price - tp_distance;
        trade.Sell(lotSize, _Symbol, price, sl, tp, "Sell opened by Advanced EA");
    }
}

//+------------------------------------------------------------------+
//| Gestionează Trailing Stop-ul                                     |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentSL = PositionGetDouble(POSITION_SL);
                double currentTP = PositionGetDouble(POSITION_TP);
                long posType = (long)PositionGetInteger(POSITION_TYPE);

                double trailingStart = TrailingStart_Pips * _pipValue;

                if(posType == POSITION_TYPE_BUY)
                {
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    if(currentPrice - openPrice > trailingStart)
                    {
                        double newSL = currentPrice - (TrailingStop_Pips * _pipValue);
                        if(newSL > currentSL) trade.PositionModify(ticket, newSL, currentTP);
                    }
                }
                else if(posType == POSITION_TYPE_SELL)
                {
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    if(openPrice - currentPrice > trailingStart)
                    {
                        double newSL = currentPrice + (TrailingStop_Pips * _pipValue);
                        if(newSL < currentSL || currentSL == 0) trade.PositionModify(ticket, newSL, currentTP);
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
