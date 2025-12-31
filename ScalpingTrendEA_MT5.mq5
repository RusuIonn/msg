//+------------------------------------------------------------------+
//|    IntradayTrendEA_MT5.mq5 (Robust Version)                      |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputuri
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15; // Timeframe pentru indicatori
input ulong MagicNumber = 12345;         // Număr Magic pentru a identifica tranzacțiile EA-ului
input double Lots = 0.1;
input int FastMA_Period = 14;
input int SlowMA_Period = 50;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
input int RSI_Period = 14;
input double RSI_Buy_Level = 40;
input double RSI_Sell_Level = 60;
input double StopLoss_Pips = 50.0;       // Stop Loss în pips
input double TakeProfit_Pips = 100.0;    // Take Profit în pips
input double TrailingStart_Pips = 25.0;  // Când să înceapă trailing-ul, în pips
input double TrailingStop_Pips = 15.0;   // Distanța trailing stop-ului față de preț, în pips

//--- Handle indicatori
int handleFastMA, handleSlowMA, handleRSI;

//--- Variabile globale
double _pipValue;   // Valoarea unui pip, calculată dinamic
bool isNewBar;      // Flag pentru bară nouă

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Calculare valoare pip
    if(_Digits == 3 || _Digits == 5)
    {
        _pipValue = _Point * 10;
    }
    else
    {
        _pipValue = _Point;
    }

    //--- Inițializare indicatori pe timeframe-ul selectat
    handleFastMA = iMA(_Symbol, Timeframe, FastMA_Period, 0, MA_Method, PRICE_CLOSE);
    handleSlowMA = iMA(_Symbol, Timeframe, SlowMA_Period, 0, MA_Method, PRICE_CLOSE);
    handleRSI    = iRSI(_Symbol, Timeframe, RSI_Period, PRICE_CLOSE);

    if(handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE || handleRSI == INVALID_HANDLE)
    {
        Print("Eroare la crearea indicatorilor!");
        return(INIT_FAILED);
    }

    //--- Setare Magic Number pentru CTrade
    trade.SetExpertMagicNumber(MagicNumber);

    Print("EA Intraday MT5 activ pe timeframe ", EnumToString(Timeframe));
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Eliberare resurse
    IndicatorRelease(handleFastMA);
    IndicatorRelease(handleSlowMA);
    IndicatorRelease(handleRSI);
    Print("EA a fost oprit. Resursele au fost eliberate.");
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Gestionarea Trailing Stop rulează la fiecare tick pentru precizie
    ManageTrailingStop();

    //--- Verificăm dacă a apărut o bară nouă pe timeframe-ul de lucru
    CheckForNewBar();
    if(!isNewBar)
    {
        return; // Ieșim dacă nu este bară nouă, logica de intrare rulează o singură dată pe bară
    }

    //--- Obținem datele de pe ultimele 3 bare pentru a detecta încrucișarea pe bare închise
    double fastMA[3], slowMA[3], rsi[3];
    if(!GetIndicatorValues(0, 3, fastMA, slowMA, rsi))
    {
        return; // Eroare la citirea indicatorilor
    }

    //--- Definim valorile pentru lizibilitate (folosim index 1 și 2 - bare închise)
    // Index 0 = bara curentă (în formare), Index 1 = ultima bară închisă, Index 2 = a doua cea mai recentă bară închisă
    double fastMA_recent = fastMA[1];
    double fastMA_older = fastMA[2];
    double slowMA_recent = slowMA[1];
    double slowMA_older = slowMA[2];
    double rsi_recent = rsi[1];

    //--- Logica de tranzacționare bazată pe încrucișare pe bare închise
    bool buySignal = fastMA_older < slowMA_older && fastMA_recent > slowMA_recent && rsi_recent > RSI_Buy_Level;
    bool sellSignal = fastMA_older > slowMA_older && fastMA_recent < slowMA_recent && rsi_recent < RSI_Sell_Level;

    //--- Managementul pozițiilor
    ulong buyTicket = GetOpenPositionTicket(POSITION_TYPE_BUY);
    ulong sellTicket = GetOpenPositionTicket(POSITION_TYPE_SELL);

    // Dacă avem un semnal de cumpărare
    if(buySignal)
    {
        // Dacă există o poziție de vânzare deschisă, o închidem (inversare)
        if(sellTicket > 0)
        {
            trade.PositionClose(sellTicket);
        }
        // Dacă nu există deja o poziție de cumpărare, deschidem una nouă
        if(buyTicket == 0)
        {
            OpenPosition(ORDER_TYPE_BUY);
        }
    }

    // Dacă avem un semnal de vânzare
    if(sellSignal)
    {
        // Dacă există o poziție de cumpărare deschisă, o închidem (inversare)
        if(buyTicket > 0)
        {
            trade.PositionClose(buyTicket);
        }
        // Dacă nu există deja o poziție de vânzare, deschidem una nouă
        if(sellTicket == 0)
        {
            OpenPosition(ORDER_TYPE_SELL);
        }
    }
}

//+------------------------------------------------------------------+
//| Verifică dacă a apărut o bară nouă pe timeframe-ul specificat    |
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
    else
    {
        isNewBar = false;
    }
}

//+------------------------------------------------------------------+
//| Returnează ticket-ul unei poziții deschise de un anumit tip      |
//+------------------------------------------------------------------+
ulong GetOpenPositionTicket(ENUM_POSITION_TYPE type)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
                return PositionGetInteger(POSITION_TICKET);
            }
        }
    }
    return 0; // Nu am găsit nicio poziție de tipul specificat
}


//+------------------------------------------------------------------+
//| Obține valorile indicatorilor pentru un anumit număr de bare     |
//+------------------------------------------------------------------+
bool GetIndicatorValues(int startIndex, int count, double &fastMA[], double &slowMA[], double &rsi[])
{
    // Copiem datele în array-uri
    if(CopyBuffer(handleFastMA, 0, startIndex, count, fastMA) < count ||
       CopyBuffer(handleSlowMA, 0, startIndex, count, slowMA) < count ||
       CopyBuffer(handleRSI, 0, startIndex, count, rsi) < count)
    {
        Print("Eroare la copierea datelor din indicatori!");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Deschide o nouă poziție                                          |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
    double price, sl, tp;

    if(orderType == ORDER_TYPE_BUY)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = price - StopLoss_Pips * _pipValue;
        tp = price + TakeProfit_Pips * _pipValue;

        if(!trade.Buy(Lots, _Symbol, price, sl, tp, "Buy opened by EA"))
        {
            Print("Eroare la deschiderea poziției de Buy: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
        else
        {
            Print("Buy deschis la ", _Symbol, " cu SL=", sl, " și TP=", tp);
        }
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = price + StopLoss_Pips * _pipValue;
        tp = price - TakeProfit_Pips * _pipValue;

        if(!trade.Sell(Lots, _Symbol, price, sl, tp, "Sell opened by EA"))
        {
            Print("Eroare la deschiderea poziției de Sell: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
        else
        {
            Print("Sell deschis la ", _Symbol, " cu SL=", sl, " și TP=", tp);
        }
    }
}

//+------------------------------------------------------------------+
//| Gestionează Trailing Stop-ul                                     |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    // Iterăm prin toate pozițiile deschise
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            // Verificăm dacă poziția aparține acestui EA și acestui simbol
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentSL = PositionGetDouble(POSITION_SL);
                double currentTP = PositionGetDouble(POSITION_TP);
                long positionType = PositionGetInteger(POSITION_TYPE);

                double trailingStart = TrailingStart_Pips * _pipValue;
                double trailingStop = TrailingStop_Pips * _pipValue;

                if(positionType == POSITION_TYPE_BUY)
                {
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    if(currentPrice - openPrice > trailingStart)
                    {
                        double newSL = currentPrice - trailingStop;
                        if(newSL > currentSL)
                        {
                            trade.PositionModify(ticket, newSL, currentTP);
                        }
                    }
                }
                else if(positionType == POSITION_TYPE_SELL)
                {
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    if(openPrice - currentPrice > trailingStart)
                    {
                        double newSL = currentPrice + trailingStop;
                        if(newSL < currentSL || currentSL == 0)
                        {
                           trade.PositionModify(ticket, newSL, currentTP);
                        }
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
