/*

   MA Cross basic
   Copyright 2023, Novateq Pty Ltd
   https://orchardforex.com

*/

#define app_name  "MA Cross"
#define app_magic 232323

#property copyright "Copyright 2013-2023 Novateq Pty Ltd"
#property link "https://orchardforex.com"
#property version "1.0"
#property description "MA cross"

//
//	Inputs
//
//
//	Fast MA
//
input int                InpFastMAPeriod       = 20;          // Fast MA Bars
input ENUM_MA_METHOD     InpFastMAMethod       = MODE_EMA;    // Fast MA Method
input ENUM_APPLIED_PRICE InpFastMAAppliedPrice = PRICE_CLOSE; // Fast MA Applied Price

//
//	Slow MA
//
input int                InpSlowMAPeriod       = 50;          // Slow MA Bars
input ENUM_MA_METHOD     InpSlowMAMethod       = MODE_EMA;    // Slow MA Method
input ENUM_APPLIED_PRICE InpSlowMAAppliedPrice = PRICE_CLOSE; // Slow MA Applied Price

// sl/tp
input int                InpStopLossPips       = 50; // sl pips
input int                InpTakeProfitPips     = 50; // tp pips

//
//	Basic inputs
//
input double             InpOrderSize          = 0.01;      // Order size in lots
input int                InpMagic              = app_magic; // Magic number
input string             InpTradeComment       = app_name;  // Trade comment

// Bring in the trade class to make trading easier
#include <Trade/Trade.mqh>
CTrade        Trade;
CPositionInfo PositionInfo;

// Handles and buffers for the moving averages
int           HandleFastMA;
int           HandleSlowMA;

double        BufferFastMA[];
double        BufferSlowMA[];
const int     BufferValuesRequired = 3;

// Some global values
double        StopLoss;
double        TakeProfit;

;
//
//	Initialisation
//
int OnInit() {

   StopLoss   = PipsToDouble( InpStopLossPips );
   TakeProfit = PipsToDouble( InpTakeProfitPips );

   // Reset the new bar
   IsNewBar();

   // MT5 Specific
   Trade.SetExpertMagicNumber( InpMagic );

   HandleFastMA = iMA( Symbol(), Period(), InpFastMAPeriod, 0, InpFastMAMethod, InpFastMAAppliedPrice );
   HandleSlowMA = iMA( Symbol(), Period(), InpSlowMAPeriod, 0, InpSlowMAMethod, InpSlowMAAppliedPrice );
   ArraySetAsSeries( BufferFastMA, true );
   ArraySetAsSeries( BufferSlowMA, true );

   if ( HandleFastMA == INVALID_HANDLE || HandleSlowMA == INVALID_HANDLE ) {
      Print( "Error creating handles to indicators" );
      return INIT_FAILED;
   }
   // end MT5 Specific

   return ( INIT_SUCCEEDED );
}

void OnDeinit( const int reason ) {

   // MT5 Specific
   IndicatorRelease( HandleFastMA );
   IndicatorRelease( HandleSlowMA );
   // end MT5 Specific
}

void OnTick() {

   // Enter a trade on a cross of fast MA over slow MA
   // Exit any existing opposite at the same time
   // means there can only be one trade open at a time
   // Not a great trading strategy but a good demo

   bool newBar            = IsNewBar();
   bool conditionOpenBuy  = false;
   bool conditionOpenSell = false;

   if ( !newBar ) return;

   // Get the fast and slow ma values for bar 1 and bar 2
   if ( !FillBuffers( BufferValuesRequired ) ) return;

   // Compare, if Fast 1 is above Slow 1 and Fast 2 is not above Slow 2 then
   // there is a cross up

   conditionOpenBuy  = CrossUp( BufferFastMA, BufferSlowMA, 1 );
   conditionOpenSell = CrossDown( BufferFastMA, BufferSlowMA, 1 );

   if ( conditionOpenBuy ) {
      TradeOpenSLTPGap( ORDER_TYPE_BUY, InpOrderSize, InpTradeComment, StopLoss, TakeProfit );
      return;
   }
   if ( conditionOpenSell ) {
      TradeOpenSLTPGap( ORDER_TYPE_SELL, InpOrderSize, InpTradeComment, StopLoss, TakeProfit );
   }

   //
}

double PipsToDouble( int pips ) { return PointsToDouble( PipsToPoints( pips ) ); }

int    PipsToPoints( int pips ) { return pips * ( ( Digits() == 3 || Digits() == 5 ) ? 10 : 1 ); }

double PointsToDouble( int points ) {

   return points * Point(); // just number of points * size of a point
}

bool IsNewBar() {

   static datetime previous_time = 0;
   datetime        current_time  = iTime( Symbol(), Period(), 0 );
   if ( previous_time != current_time ) {
      previous_time = current_time;
      return true;
   }
   return false;
}

bool CrossUp( double &arr1[], double &arr2[], int index1, int index2 = -1 ) {

   if ( index2 < 0 ) index2 = index1 + 1;
   bool cross = ( arr1[index1] > arr2[index1] ) && !( arr1[index2] > arr2[index2] );
   return cross;
}

bool CrossDown( double &arr1[], double &arr2[], int index1, int index2 = -1 ) {

   if ( index2 < 0 ) index2 = index1 + 1;
   bool cross = ( arr1[index1] < arr2[index1] ) && !( arr1[index2] < arr2[index2] );
   return cross;
}

// MT5 Specific

// Load values from the indicators into buffers
bool FillBuffers( int valuesRequired ) {

   if ( CopyBuffer( HandleFastMA, 0, 0, valuesRequired, BufferFastMA ) < valuesRequired ) {
      Print( "Insufficient results from fast MA" );
      return false;
   }
   if ( CopyBuffer( HandleSlowMA, 0, 0, valuesRequired, BufferSlowMA ) < valuesRequired ) {
      Print( "Insufficient results from slow MA" );
      return false;
   }

   return true;
}

// Open a market price trade given a value gap to stop loss and take profit
void TradeOpenSLTPGap( ENUM_ORDER_TYPE type, double volume, string tradeComment, double stopLoss = 0, double takeProfit = 0 ) {

   double price;
   double closePrice;
   double sl         = 0;
   double tp         = 0;
   double stopsLevel = PointsToDouble( ( int )SymbolInfoInteger( Symbol(), SYMBOL_TRADE_STOPS_LEVEL ) );

   if ( stopLoss > 0 && stopLoss < stopsLevel ) return;
   if ( takeProfit > 0 && takeProfit < stopsLevel ) return;

   if ( type == ORDER_TYPE_BUY ) {
      price      = SymbolInfoDouble( Symbol(), SYMBOL_ASK );
      closePrice = SymbolInfoDouble( Symbol(), SYMBOL_BID );
      if ( stopLoss > 0 ) sl = closePrice - stopLoss;
      if ( takeProfit > 0 ) tp = price + takeProfit;
   }
   else {
      price      = SymbolInfoDouble( Symbol(), SYMBOL_BID );
      closePrice = SymbolInfoDouble( Symbol(), SYMBOL_ASK );
      if ( stopLoss > 0 ) sl = closePrice + stopLoss;
      if ( takeProfit > 0 ) tp = price - takeProfit;
   }

   price = NormalizeDouble( price, Digits() );
   sl    = NormalizeDouble( sl, Digits() );
   tp    = NormalizeDouble( tp, Digits() );

   if ( !Trade.PositionOpen( Symbol(), type, volume, price, sl, tp, tradeComment ) ) {
      Print( "Open failed for %s, %s, price=%f, sl=%f, tp=%f", Symbol(), EnumToString( type ), price, sl, tp );
   }
}

// end MT5 Specific

// That's all folks
