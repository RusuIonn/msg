//+------------------------------------------------------------------+
//|    AdvancedTrendEA_MT5.mq5 (with Multi-Timeframe Filter)         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputuri Strategie de Execuție
input ENUM_TIMEFRAMES Execution_Timeframe = PERIOD_M15; // Timeframe-ul pe care se execută tranzacțiile
input int FastMA_Period = 14;
input int SlowMA_Period = 50;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
input int RSI_Period = 14;
// Nivelurile RSI sunt setate implicit la 50 pentru o strategie simetrică.
// Pentru o confirmare mai puternică a momentum-ului, se pot folosi valori asimetrice (ex: Cumpărare > 55, Vânzare < 45).
input double RSI_Buy_Level = 50.0;
input double RSI_Sell_Level = 50.0;

//--- Inputuri Filtru de Trend Multi-Timeframe
input ENUM_TIMEFRAMES Trend_Timeframe = PERIOD_H1; // Timeframe-ul pentru definirea trendului principal
input int Trend_MA_Period = 200;              // Perioada mediei mobile pentru trend
input double NeutralZone_ATR_Multiplier = 1.0; // Multiplicator ATR pentru zona neutră a trendului

//--- Inputuri Managementul Banilor și Riscului
input ulong MagicNumber = 54321;         // Număr Magic unic pentru acest EA
input double RiskPercent = 1.0;           // Procentul din cont riscat pe tranzacție
input int MaxOpenTrades = 5;               // Numărul maxim de tranzacții deschise simultan
input int ATR_Period = 14;                 // Perioada pentru ATR (pe timeframe-ul de execuție)
input double ATR_StopLoss_Multiplier = 2.0; // Multiplicator ATR pentru Stop Loss
input double ATR_TakeProfit_Multiplier = 4.0;// Multiplicator ATR pentru Take Profit
input double ATR_MinVolatility_Pips = 5.0; // Volatilitate minimă (ATR în pips) pentru a tranzacționa

//--- Inputuri Trailing Stop
input double TrailingStart_Pips = 25.0;  // Când să înceapă trailing-ul, în pips
input double TrailingStop_Pips = 15.0;   // Distanța trailing stop-ului față de preț, în pips

//--- Handle indicatori
int h_fastMA, h_slowMA, h_RSI, h_ATR, h_trendMA, h_trendATR;

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

    // Inițializare indicatori pentru timeframe-ul de execuție
    h_fastMA = iMA(_Symbol, Execution_Timeframe, FastMA_Period, 0, MA_Method, PRICE_CLOSE);
    h_slowMA = iMA(_Symbol, Execution_Timeframe, SlowMA_Period, 0, MA_Method, PRICE_CLOSE);
    h_RSI    = iRSI(_Symbol, Execution_Timeframe, RSI_Period, PRICE_CLOSE);
    h_ATR    = iATR(_Symbol, Execution_Timeframe, ATR_Period);

    // Inițializare indicatori pentru filtrul de trend
    h_trendMA = iMA(_Symbol, Trend_Timeframe, Trend_MA_Period, 0, MA_Method, PRICE_CLOSE);
    h_trendATR = iATR(_Symbol, Trend_Timeframe, ATR_Period);

    if(h_fastMA==INVALID_HANDLE || h_slowMA==INVALID_HANDLE || h_RSI==INVALID_HANDLE || h_ATR==INVALID_HANDLE || h_trendMA==INVALID_HANDLE || h_trendATR==INVALID_HANDLE)
    {
        Print("Eroare la crearea unuia sau mai multor indicatori!");
        return(INIT_FAILED);
    }

    trade.SetExpertMagicNumber(MagicNumber);
    Print("Advanced Trend EA (MTF) activ. Trend pe ", EnumToString(Trend_Timeframe), ", Execuție pe ", EnumToString(Execution_Timeframe));
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(h_fastMA);
    IndicatorRelease(h_slowMA);
    IndicatorRelease(h_RSI);
    IndicatorRelease(h_ATR);
    IndicatorRelease(h_trendMA);
    IndicatorRelease(h_trendATR);
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

    int openTrades = CountOpenTrades();
    if (isNewBar) Print("Verificare MaxOpenTrades: Curente = ", openTrades, ", Limită = ", MaxOpenTrades);

    if(openTrades >= MaxOpenTrades) return;

    //--- Obținerea și validarea direcției trendului principal
    double trendMA[1], trendATR[1];
    if(CopyBuffer(h_trendMA, 0, 1, 1, trendMA) <= 0 || CopyBuffer(h_trendATR, 0, 1, 1, trendATR) <= 0)
    {
        Print("Eroare la copierea datelor din indicatorii de trend!");
        return;
    }

    double neutralZoneDistance = trendATR[0] * NeutralZone_ATR_Multiplier;
    double upperBand = trendMA[0] + neutralZoneDistance;
    double lowerBand = trendMA[0] - neutralZoneDistance;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool isUptrend = currentPrice > upperBand;
    bool isDowntrend = currentPrice < lowerBand;

    //--- Obținerea indicatorilor de pe timeframe-ul de execuție (doar ultima bară închisă)
    double fastMA[1], slowMA[1], rsi[1], atr[1];
    if(!GetExecutionIndicators(fastMA, slowMA, rsi, atr)) return;

    double atr_pips = atr[0] / _pipValue;
    if(atr_pips < ATR_MinVolatility_Pips) return;

    double fastMA_recent = fastMA[0];
    double slowMA_recent = slowMA[0];
    double rsi_recent = rsi[0];

    //--- Logica de semnal bazată pe STARE, filtrată de trendul principal
    bool buySignal = fastMA_recent > slowMA_recent && rsi_recent > RSI_Buy_Level;
    bool sellSignal = fastMA_recent < slowMA_recent && rsi_recent < RSI_Sell_Level;

    // Doar luăm în considerare semnalele care sunt în direcția trendului principal
    if(isUptrend && buySignal) OpenPosition(ORDER_TYPE_BUY, atr[0]);
    if(isDowntrend && sellSignal) OpenPosition(ORDER_TYPE_SELL, atr[0]);
}

//+------------------------------------------------------------------+
//| Verifică bară nouă pe timeframe-ul de execuție                   |
//+------------------------------------------------------------------+
void CheckForNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, Execution_Timeframe, SERIES_LASTBAR_DATE);
    if(lastBarTime < currentBarTime)
    {
        isNewBar = true;
        lastBarTime = currentBarTime;
    }
    else isNewBar = false;
}

//+------------------------------------------------------------------+
//| Obține valorile indicatorilor de pe ultima bară închisă          |
//+------------------------------------------------------------------+
bool GetExecutionIndicators(double &fastMA[], double &slowMA[], double &rsi[], double &atr[])
{
    // Copiem datele de pe ultima bară închisă (index 1), o singură valoare
    if(CopyBuffer(h_fastMA, 0, 1, 1, fastMA) < 1 ||
       CopyBuffer(h_slowMA, 0, 1, 1, slowMA) < 1 ||
       CopyBuffer(h_RSI, 0, 1, 1, rsi) < 1 ||
       CopyBuffer(h_ATR, 0, 1, 1, atr) < 1)
    {
        Print("Eroare la copierea datelor din indicatorii de execuție!");
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

    // Corecție pentru a respecta nivelul minim de stop al brokerului
    double min_stop_level_distance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if (sl_distance < min_stop_level_distance)
    {
        Print("Atenție: SL calculat (", sl_distance, ") este mai mic decât minimul brokerului (", min_stop_level_distance, "). Se ajustează.");
        sl_distance = min_stop_level_distance;
    }

    double lotSize = CalculateLotSize(sl_distance);
    if(lotSize <= 0)
    {
        Print("Calculul lotului a eșuat. Lot size este zero.");
        return;
    }

    if(orderType == ORDER_TYPE_BUY)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = NormalizeDouble(price - sl_distance, _Digits);
        tp = NormalizeDouble(price + tp_distance, _Digits);
        trade.Buy(lotSize, _Symbol, price, sl, tp, "Buy opened by Advanced EA");
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = NormalizeDouble(price + sl_distance, _Digits);
        tp = NormalizeDouble(price - tp_distance, _Digits);
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
                        double newSL = NormalizeDouble(currentPrice - (TrailingStop_Pips * _pipValue), _Digits);
                        if(newSL > currentSL) trade.PositionModify(ticket, newSL, currentTP);
                    }
                }
                else if(posType == POSITION_TYPE_SELL)
                {
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    if(openPrice - currentPrice > trailingStart)
                    {
                        double newSL = NormalizeDouble(currentPrice + (TrailingStop_Pips * _pipValue), _Digits);
                        if(newSL < currentSL || currentSL == 0) trade.PositionModify(ticket, newSL, currentTP);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Numără tranzacțiile deschise de acest EA                         |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                count++;
            }
        }
    }
    return count;
}
//+------------------------------------------------------------------+
