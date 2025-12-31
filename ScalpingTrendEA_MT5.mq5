//+------------------------------------------------------------------+
//|    ScalpingTrendEA_MT5.mq5 (Corectat Final)                      |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputuri
input ulong MagicNumber = 12345;         // Număr Magic pentru a identifica tranzacțiile EA-ului
input double Lots = 0.1;
input int FastMA_Period = 14;
input int SlowMA_Period = 50;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
input int RSI_Period = 14;
input double RSI_Buy_Level = 40;
input double RSI_Sell_Level = 60;
input double StopLoss_Pips = 10.0;       // Stop Loss în pips
input double TakeProfit_Pips = 20.0;     // Take Profit în pips
input double TrailingStart_Pips = 5.0;   // Când să înceapă trailing-ul, în pips
input double TrailingStop_Pips = 2.0;    // Distanța trailing stop-ului față de preț, în pips

//--- Handle indicatori
int handleFastMA, handleSlowMA, handleRSI;

//--- Variabile globale
bool isNewBar = false;
double _pipValue; // Valoarea unui pip, calculată dinamic

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

    //--- Inițializare indicatori
    handleFastMA = iMA(_Symbol, PERIOD_M1, FastMA_Period, 0, MA_Method, PRICE_CLOSE);
    handleSlowMA = iMA(_Symbol, PERIOD_M1, SlowMA_Period, 0, MA_Method, PRICE_CLOSE);
    handleRSI    = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);

    if(handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE || handleRSI == INVALID_HANDLE)
    {
        Print("Eroare la crearea indicatorilor!");
        return(INIT_FAILED);
    }

    //--- Setare Magic Number pentru CTrade
    trade.SetExpertMagicNumber(MagicNumber);

    Print("EA scalping MT5 activ!");
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
    //--- Logica de Trailing Stop trebuie să ruleze la fiecare tick
    ManageTrailingStop();

    //--- Verificare bară nouă pentru logica de intrare
    CheckForNewBar();
    if(!isNewBar)
    {
        return; // Ieșim dacă nu este bară nouă, logica de intrare nu se execută
    }

    //--- Obținere date indicatori (de pe bara închisă - index 1)
    double fastMA_prev, slowMA_prev, rsi_prev;
    if(!GetIndicatorValues(1, fastMA_prev, slowMA_prev, rsi_prev))
    {
        return; // Nu am putut obține valorile, ieșim
    }

    //--- Logica de tranzacționare
    if(!HasOpenPosition()) // Verificăm dacă NU avem deja o poziție deschisă pentru acest simbol/magic
    {
        // Condiție Buy
        if(fastMA_prev > slowMA_prev && rsi_prev > RSI_Buy_Level)
        {
            OpenPosition(ORDER_TYPE_BUY);
        }
        // Condiție Sell
        else if(fastMA_prev < slowMA_prev && rsi_prev < RSI_Sell_Level)
        {
            OpenPosition(ORDER_TYPE_SELL);
        }
    }
}

//+------------------------------------------------------------------+
//| Verifică dacă a apărut o bară nouă                               |
//+------------------------------------------------------------------+
void CheckForNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_LASTBAR_DATE);

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
//| Verifică dacă există o poziție deschisă de acest EA pe simbolul curent |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) // Selectăm poziția pentru a-i putea citi proprietățile
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                return true; // Am găsit o poziție care corespunde
            }
        }
    }
    return false; // Nu am găsit nicio poziție care să corespundă
}


//+------------------------------------------------------------------+
//| Obține valorile indicatorilor pentru o anumită bară              |
//+------------------------------------------------------------------+
bool GetIndicatorValues(int barIndex, double &fastMA, double &slowMA, double &rsi)
{
    double tempFastMA[1], tempSlowMA[1], tempRSI[1];

    if(CopyBuffer(handleFastMA, 0, barIndex, 1, tempFastMA) <= 0 ||
       CopyBuffer(handleSlowMA, 0, barIndex, 1, tempSlowMA) <= 0 ||
       CopyBuffer(handleRSI, 0, barIndex, 1, tempRSI) <= 0)
    {
        Print("Eroare la copierea datelor din indicatori!");
        return false;
    }

    fastMA = tempFastMA[0];
    slowMA = tempSlowMA[0];
    rsi = tempRSI[0];
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
                    // Verificăm dacă profitul a atins nivelul de start al trailing-ului
                    if(currentPrice - openPrice > trailingStart)
                    {
                        double newSL = currentPrice - trailingStop;
                        // Mutăm SL-ul doar dacă noul SL este mai bun (mai mare) decât cel curent
                        if(newSL > currentSL)
                        {
                            if(!trade.PositionModify(ticket, newSL, currentTP))
                            {
                                Print("Eroare la modificarea Trailing Stop pentru Buy: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                            }
                        }
                    }
                }
                else if(positionType == POSITION_TYPE_SELL)
                {
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    // Verificăm dacă profitul a atins nivelul de start al trailing-ului
                    if(openPrice - currentPrice > trailingStart)
                    {
                        double newSL = currentPrice + trailingStop;
                        // Mutăm SL-ul doar dacă noul SL este mai bun (mai mic) decât cel curent
                        if(newSL < currentSL || currentSL == 0)
                        {
                           if(!trade.PositionModify(ticket, newSL, currentTP))
                           {
                               Print("Eroare la modificarea Trailing Stop pentru Sell: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                           }
                        }
                    }
                }
                // Deoarece EA-ul deschide o singură poziție pe simbol, putem ieși din buclă după ce am găsit-o și am procesat-o
                break;
            }
        }
    }
}
//+------------------------------------------------------------------+
