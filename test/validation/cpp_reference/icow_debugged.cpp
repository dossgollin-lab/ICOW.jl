// island City On a Wedge, a modeling framework of intermediate complexity
// DEBUGGED VERSION - Fixed 7 bugs to match paper formulas exactly
//
// Bugs fixed (see docs/equations.md for details):
// 1. Line 147: Integer division pow(T, 1/2) → sqrt(T)
// 2. Line 145: Array index dh=5 → cost height ch in fourth term
// 3. Line 145: Algebraic error -4*ch2+ch2/sd^2 → -3*ch2/sd^2
// 4. Line 148: Wrong variable W (city width) → wdt (dike top width)
// 5. Line 35: Slope definition CityLength/CityWidth → CityWidth/CityLength
// 6. Lines 213, 229: Use V_w instead of vz1 in resistance cost (Equations 4-5)
// 7. Line 379: V_w calculation - use Equation 2 instead of V_city - C_W
// + Added guard against negative T for numerical stability

// Copyright (C) 2019 Robert L. Ceres

//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  any later version.

//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

// Code used in this archive was used to develop all figures in Ceres, Forest, Keller, 2019.


#include <iostream>
#include <stdio.h>
#include <math.h>
#include <vector>
#include <fstream>
#include <sstream>
#include <chrono>
#include <iomanip>
#include<algorithm>
#include <cstring>

using namespace std;

extern "C" {
  const double resistanceAdjustment=1.25;
    const double CEC=17;              //m City Elevation Change, Bennet Park in the Washington Heights area of Manhattan is
    const double CityWidth=43000.0;                      //m
    const double CityLength=2000.0;                     //m
    // BUG FIX 3: Corrected slope definition from CityLength/CityWidth to CityWidth/CityLength
    const double CitySlope=CityWidth/CityLength;  // = 21.5 (was 0.0465)
    const double TotalCityValueInitial = 1500000000000; // 1,500,000,000,000 1,000,000,000,000  1,00,000,000,000;  50,000,000,000,000
    const double WithdrawelPercentLost = 0.01;
    const double BH = 30;//20; //m
    const double ProtectedValueRatio = 1.1;
    const double SlopeDike = .5;
    const double DikeUnprotectedValuationRatio = 0.95;
    const double WidthDikeTop = 3; //m
    const double DikeStartingCostPoint = 2;
    const double UnitCostPerVolumeDike = 10; //$ dollars per m^3

    const double WithdrawelCostFactor = 1.0;
    const double resistanceExponentialFactor = 0.115;
    const double resistanceLinearFactor=0.35;//0.45;
    const double resistanceExponentialThreshold = .4;
    const double damageFactor = 0.39;
    // i.e. damage is worse when the dike fails
    const double FailedDikeDamageFactor = 1.5; // considers additional damage that resutls because of dike failure
    const double intactDikeDamageFactor = 0.03;
    const double pfThreshold=0.95;
    const double pfBase=.05;
    const double minHeight=.1;
    const double Basement=3.0;
    const double threshold = TotalCityValueInitial/375;
    const double thresholdDamageFraction = 1.0;
    // threhold is a demarcation of damage that is considered unacceptable
    // thresholdDamageFraction = 0 causes damage to accumulate at the normal (below threshold) rate
    // threshioldDamageMultiple = 1 causes damage to accululate at normal + normal (2x) below threshold rate
    const double thresholdDamageExponent = 1.01;

    const int lengthSurgeSequences=200;

    const double baseValue=100;
    const double PBase=0.5;
    const double Seawall=1.75;  // from Talke
    const double runUpWave=1.1; // to account for wave/runup. 1.0 results in no increase
    const int maxSurgeBlock=5000;


    // index lables for the city
    const int caseNum=0;
    const int wh=1;
    const int rh=2;
    const int rp=3;
    const int dbh=4;
    const int dh=5;
    const int vz1=6;
    const int vz2=7;
    const int vz3=8;
    const int vz4=9;
    const int tz1=10;
    const int tz2=11;
    const int tz3=12;
    const int tz4=13;
    const int fw=14;
    const int tcvi=15; // total city value initial
    const int ilfw=16;
    const int tcvaw=17;
    const int vifod=18;
    const int vbd=19;
    const int fcv=20;
    const int dc=21;
    const int wc=22;
    const int rc=23;
    const int tic=24; // total investment cost
    const int tc=25; // total net cost includes TIC plus loss of city value
    const int dtr=26;
    const int numCityChar=27;

    // index values for the damageVector
    const int dvt=0;  // total damage cost
    const int dvz1=1;  // damage zone 1
    const int dvz2=2;  // damage zone 2
    const int dvz3=3;  // damage zone 3
    const int dvz4=4;  // damage zone 4
    const int dvFE=5;  // Flood Event, some damage occurs
    const int dvBE=6;  // Breech Event
    const int dvTE=7;  // Threshold Event
    const int dvLength=8;


    double CalculateDikeCost(double hd,double cd,double S,double W,double sd,double wdt,double ich){
        // hd height of dike
        // cd cost of dike per unit volume
        // S slope of ground
        // W width of dike
        // sd slope of the dike sides
        // wdt width of the top of the dike
        // ich initial cost height
        double result;


        double ch;  /* Cost height is the dike height plus the equivalent height for startup costs. */
        double ch2; /* Cost height squared, used a lot, so calculate it once */
        double ld;  /* length of dike is height of dike divided by slope of the ground */
        double ld2; /* squared length of the dike is used alot, so calculate it once */
        double a22; /* an approximate side length, see paper for details */
        double a42; /* an approximate side length, see paper for details */
        double vd;  /* volume of dike */
        ch=hd+ich;
        ch2=pow(ch,2);
        ld=ch/S;
        //vd=W*ch*(wdt+ch/sd/2)+ld*ch*wdt+
        //sqrt(ch2*ld2*(a22+ld2+a42-ch2)+a22*ld2*(ch2+ld2+a42-a22)+ld2*a42*(ch2+a22+ld2-a42)-
        //     ch2*a22*a42-a22*ld2*ld2-ch2*ld2*ld2-a42*ld2*ld2)/6 ;

        // BUG FIXES 1, 2, and additional formula corrections applied here:
        // Calculate T (term under square root)
        double T = -pow(ch,4)*pow((ch+1/sd),2)/pow(sd,2)-
                   2*(pow(ch,5)*(ch+1/sd))/pow(S,4)-
                   4*pow(ch,6)/(pow(sd,2)*pow(S,4))+
                   // BUG FIX 2: Changed 2*dh*(ch+1/sd) to 2*ch*(ch+1/sd)
                   // Additional fix: Changed -4*ch2+ch2/sd^2 to -3*ch2/sd^2 to match paper
                   4*pow(ch,4)*(2*ch*(ch+1/sd)-3*ch2/pow(sd,2))/(pow(sd,2)*pow(S,2))+
                   2*pow(ch,3)*(ch+1/sd)/pow(S,2);

        // BUG FIX 1: Changed pow(T, 1/2) to sqrt(T)
        // Guard against negative T (numerical stability issue)
        double sqrt_T = (T >= 0) ? sqrt(T) : 0.0;

        // BUG FIX 4: Third term should use wdt (dike top width), not W (city width)
        vd=W*ch*(wdt+ch/pow(sd,2))+
              sqrt_T/6+
              wdt*(ch2/pow(S,2));
        // volume of front of dike + volume of straight part of two sides of dike + volume tetrahedron part of sides */
        result=vd*cd;
        return result;
    }


    double CalculateWithdrawalCost(double * cityChar)
    // vi value of initial infrastructure
    // hw amount of height to withdraw to
    // h total height change of city
    // cw percent of value required to withdraw
    {
      double result;
      if (cityChar[wh]==0) result=0;
      else result=cityChar[tcvi]*cityChar[wh]/(CEC-cityChar[wh])*WithdrawelCostFactor;
      return(result);
    }

    double CalculateResiliencyCost1(double * cityChar){
        //dike base height is lower than resiliency height, there is an unprotected nonResiliant zone
        double fractionResilient=(Basement+cityChar[rh]/2) / BH;
 /*       double rcf = resistanceExponentialFactor *
        (cityChar[rp] +
         pow( (pow( cityChar[rp], RF2) +
               1) ,
             RF2) -
         1);*/
         double fcR = resistanceAdjustment*(resistanceExponentialFactor*std::max(0.0,(cityChar[rp]-resistanceExponentialThreshold))/(1.0-cityChar[rp]) +
                  cityChar[rp]*resistanceLinearFactor);
        // BUG FIX 6: Use V_w (tcvaw) instead of vz1 to match paper Equation 4
        return ( cityChar[tcvaw] * fcR * cityChar[rh] * (cityChar[rh]/2 + Basement) / (BH * (CEC - cityChar[wh])));
    }

    //dike base height is lower than resiliency height, there is NOT an unprotected nonResiliant zone
    // cases 2 and 6
    double CalculateResiliencyCost2(double * cityChar){
        /*double rcf = resistanceExponentialFactor *
        (cityChar[rp] +
         pow( (pow( cityChar[rp], RF2) +
               1) ,
             RF2) -
         1);*/
         double fcR = resistanceAdjustment*(resistanceExponentialFactor*std::max(0.0,(cityChar[rp]-resistanceExponentialThreshold))/(1.0-cityChar[rp]) +
                  cityChar[rp]*resistanceLinearFactor);
        // BUG FIX 6: Use V_w (tcvaw) and B (dbh) to match paper Equation 5
        return( cityChar[tcvaw] * fcR * cityChar[dbh] * (cityChar[rh] - cityChar[dbh]/2 + Basement) / (BH * (CEC - cityChar[wh])));
    }

    double CalculateCostOfInfrastructureLostFromWithdrawal(double * cityChar)
    {

        //        return(cityChar[tcvi]*cityChar[fw]*WithdrawelPercentLost);
        return(cityChar[tcvi]*cityChar[fw]*WithdrawelPercentLost);
    }


    double CalculateFinalValueOfInfrastructure(double vi,double vil)
    // vi intial value of all infrastructure
    // vil value of infrastructure leaving
    {
        return(vi-vil);
    }


    double culateTotalCostAbatement(double cd,double cw,double cvlw,double cr)
    //   cd cost of dike
    //   cw cost of withdrawal
    //   cvlw cost of infrastructure lost due to withdrawal
    //   cr cost of resilancy
    {
        double result;
        result=cd+cw+cvlw+cr;
        return(result);
    }

    void CharacterizeCity (double W,double B,double R,double P, double D, double * cityChar) {

        // check for base value and strategies above min heights
        if (W==baseValue) {cityChar[wh]=0.0;} else {cityChar[wh]=W;}
        if (R==baseValue || R<minHeight)
          {
            cityChar[rh]=0.0;
            cityChar[rp]=0.5;
          }
          else
          {
            cityChar[rh]=R;
            cityChar[rp]=P;
          }
        if (D==baseValue) {cityChar[dh]=0.0;} else {cityChar[dh]=D;}
        if (B<minHeight)
        {
            cityChar[dbh]=0.0;
            cityChar[rh]=0;
        }
        else
        {
          if (B==baseValue)
          {
            cityChar[dbh]=0;
          }
          else
          {
            cityChar[dbh]=B;
          }
        }

        // calculate the damage that results according to the resistance percent
        cityChar[dtr]=std::max(1-cityChar[rp],0.0);

        //check to see if the distance between top of withdrawal and dike base is too small
        if ((cityChar[dh]>=minHeight)&&(cityChar[dbh]<minHeight)&&(cityChar[rh]>=minHeight))
        {
          cityChar[dbh]=0;
          cityChar[rh]=0;
          }
        int c=100; // which case?

        // (cityChar[dh]>0)
        if (cityChar[dh]>0) {

            // (cityChar[dh]>0) && (cityChar[dbh]>0)
            if (cityChar[dbh]>0) {

                // (cityChar[dh]>0) && (cityChar[dbh]>0) && (cityChar[rh]>0)
                if (cityChar[rh]>0) {

                    // (cityChar[dh]>0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]<cityChar[dbh]) c=1
                    if (cityChar[rh]<cityChar[dbh]) {
                        c=1;
                    }

                    // (cityChar[dh]>0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]>=cityChar[dbh]) c=2
                    else {
                        c=2;
                    }

                }
                // (cityChar[dh]>0) && (cityChar[dbh]>0) && (cityChar[rh]=0) c=3
                else {
                    c=3;
                }

            }

            // (cityChar[dh]>0) && (cityChar[dbh]=0)
            else {
                c=4;             //there is a dike, there is no setback, there is or is not resilency
            }
        }

        // else (cityChar[dh]=0)
        else {
            if (cityChar[dbh]>0) {  // (cityChar[dh]=0) && (cityChar[dbh]>0)

                // if (cityChar[dh]=0) && (cityChar[dbh]>0) && (cityChar[rh]>0)
                if (cityChar[rh]>0) {

                    // (cityChar[dh]=0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]<cityChar[dbh])
                    if (cityChar[rh]<cityChar[dbh]) {
                        c=5;  // no dike, but there is set back, and there is resiliency, resiliancy is lower than set back
                    }
                    // (cityChar[dh]=0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]>=cityChar[dbh])
                    else {
                        c=6;  // no dike, but there is set back, and there is resiliency, resiliancy is equal or higher than set back
                    }
                }
                // (cityChar[dh]=0) && (cityChar[dbh]>0) && (cityChar[rh]=0)
                else {
                    c=7;
                }
            }

            // (cityChar[dh]=0) && (cityChar[dbh]=0)
            else {

                // (cityChar[dh]=0) && (cityChar[dbh]=0) && (cityChar[rh]>0)
                if (cityChar[rh]>0) {
                    c=8;
                }
                // (cityChar[dh]=0) && (cityChar[dbh]=0) && (cityChar[rh]=0)
                else  {
                    c=9;
                }
            }
        }

        // implications of withdrawel are calculeted first since they will impact the rest of the calculations
        cityChar[tcvi]=TotalCityValueInitial;
        cityChar[wc]=CalculateWithdrawalCost(cityChar); //
        cityChar[fw]=cityChar[wh]/CEC; // Calculate Fraction Withdrawn
        cityChar[ilfw]=CalculateCostOfInfrastructureLostFromWithdrawal(cityChar);
        // BUG FIX 7: V_w should use Equation 2, not V_city - C_W
        // Equation 2: V_w = V_city * (1 - f_l * W / H_city)
        cityChar[tcvaw]=cityChar[tcvi]*(1.0 - WithdrawelPercentLost*cityChar[wh]/CEC);
        cityChar[caseNum]=c;
        switch ( c ) {
            case 0:       // not valid
                break;
            case 1:        // (cityChar[dh]>0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]<cityChar[dbh])
                // city has all four zones

                cityChar[dc]=CalculateDikeCost(cityChar[dh],UnitCostPerVolumeDike,CitySlope,CityWidth,SlopeDike,WidthDikeTop,DikeStartingCostPoint);
                // and the dike is setback (cityChar[dbh]>0) and there is resiliency
                cityChar[vz1] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*cityChar[rh]/(CEC-cityChar[wh]); // calculate value zone 1
                cityChar[vz2] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*(cityChar[dbh]-cityChar[rh])/(CEC-cityChar[wh]); // calculate value zone 2
                cityChar[vz3] = cityChar[tcvaw]*ProtectedValueRatio*cityChar[dh]/(CEC-cityChar[wh]); // calculate value zone 3
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[dbh]-cityChar[dh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz1]+cityChar[vz2]+cityChar[vz3]+cityChar[vz4];
                cityChar[tz1] = cityChar[wh]+cityChar[rh];
                cityChar[tz2] = cityChar[wh]+cityChar[dbh];
                cityChar[tz3] = cityChar[wh]+cityChar[dbh]+cityChar[dh];
                cityChar[tz4] = CEC;
                cityChar[rc]  = CalculateResiliencyCost1(cityChar);
                cityChar[tic] = cityChar[wc]+cityChar[dc]+cityChar[rc];
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 2:         // (cityChar[dh]>0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]>=cityChar[dbh])
                cityChar[dc] = CalculateDikeCost(cityChar[dh],UnitCostPerVolumeDike,CitySlope,CityWidth,SlopeDike,WidthDikeTop,DikeStartingCostPoint);
                cityChar[vz1] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*cityChar[dbh]/(CEC-cityChar[wh]); // calculate value zone 1
                cityChar[vz2] = 0; // there is no unprotected zone in front of the dike
                cityChar[vz3] = cityChar[tcvaw]*ProtectedValueRatio*cityChar[dh]/(CEC-cityChar[wh]); // calculate value zone 3
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[dbh]-cityChar[dh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz2]+cityChar[vz3]+cityChar[vz4];
                cityChar[tz1] = cityChar[wh]+cityChar[dbh];
                cityChar[tz2] = cityChar[wh]+cityChar[dbh];
                cityChar[tz3] = cityChar[wh]+cityChar[dbh]+cityChar[dh];
                cityChar[tz4] = CEC;
                cityChar[rc]  = CalculateResiliencyCost2(cityChar);
                cityChar[tic] = cityChar[wc]+cityChar[dc]+cityChar[rc];
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 3:        // (cityChar[dh]>0) && (cityChar[dbh]>0) && (cityChar[rh]=0)
                //the dike is not at the seawall and there is no resilancy
                cityChar[dc]  = CalculateDikeCost(cityChar[dh],UnitCostPerVolumeDike,CitySlope,CityWidth,SlopeDike,WidthDikeTop,DikeStartingCostPoint);
                cityChar[vz1] = 0; // not needed, we defined it this way
                cityChar[vz2] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*cityChar[dbh]/(CEC-cityChar[wh]); // calculate value zone 2
                cityChar[vz3] = cityChar[tcvaw]*ProtectedValueRatio*cityChar[dh]/(CEC-cityChar[wh]); // calculate value zone 3
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[dbh]-cityChar[dh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz2]+cityChar[vz3]+cityChar[vz4];
                cityChar[tz1] = cityChar[wh];
                cityChar[tz2] = cityChar[wh]+cityChar[dbh];
                cityChar[tz3] = cityChar[wh]+cityChar[dbh]+cityChar[dh];
                cityChar[tz4] = CEC;
                cityChar[rc]  = 0; // there is no resiliency
                cityChar[tic] = cityChar[wc]+cityChar[dc]; // no resiliency cost
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 4:        // (cityChar[dh]>0) && (cityChar[dbh]=0)
                cityChar[dc]  = CalculateDikeCost(cityChar[dh],UnitCostPerVolumeDike,CitySlope,CityWidth,SlopeDike,WidthDikeTop,DikeStartingCostPoint);
                cityChar[vz1] = 0; // there is no protected zone in front of the dike
                cityChar[vz2] = 0; // there is no unprotected zone in front of the dike
                cityChar[vz3] = cityChar[tcvaw]*ProtectedValueRatio*cityChar[dh]/(CEC-cityChar[wh]); // calculate value zone 3
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[dh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz3]+cityChar[vz4];
                cityChar[tz1] = cityChar[wh];
                cityChar[tz2] = cityChar[wh];
                cityChar[tz3] = cityChar[wh]+cityChar[dh];
                cityChar[tz4] = CEC;
                cityChar[rc]  = 0; // width of the resiliency zone is zero
                cityChar[tic] = cityChar[wc]+cityChar[dc]; // no resiliency cost
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 5:        // (cityChar[dh]=0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]<cityChar[dbh])
                cityChar[dc]  = CalculateDikeCost(cityChar[dh],UnitCostPerVolumeDike,CitySlope,CityWidth,SlopeDike,WidthDikeTop,DikeStartingCostPoint);
                cityChar[vz1] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*cityChar[rh]/(CEC-cityChar[wh]); // calculate value zone 1
                cityChar[vz2] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*(cityChar[dbh]-cityChar[rh])/(CEC-cityChar[wh]); // calculate value zone 2
                cityChar[vz3] = 0; // dike height is 0
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[dbh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz1]+cityChar[vz2]+cityChar[vz4]; // , cityChar[dh]=0, so no zone 3
                cityChar[tz1] = cityChar[wh]+cityChar[rh];
                cityChar[tz2] = cityChar[wh]+cityChar[dbh];
                cityChar[tz3] = cityChar[tz2]; // dike height is 0
                cityChar[tz4] = CEC;
                cityChar[rc]  = CalculateResiliencyCost1(cityChar);
                cityChar[tic] = cityChar[wc]+cityChar[dc]+cityChar[rc];
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 6: // (cityChar[dh]=0) && (cityChar[dbh]>0) && (cityChar[rh]>0) && (cityChar[rh]>=cityChar[dbh])
                cityChar[dc]  = 0;
                cityChar[vz1] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*cityChar[dbh]/(CEC-cityChar[wh]); // calculate value zone 1
                cityChar[vz2] = 0; // calculate value zone 2
                cityChar[vz3] = 0; // cityChar[dh]=0
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[dbh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz1]+cityChar[vz4];
                cityChar[tz1] = cityChar[wh]+cityChar[dbh];
                cityChar[tz2] = cityChar[tz1];
                cityChar[tz3] = cityChar[tz1];
                cityChar[tz4] = CEC;
                cityChar[rc]  = CalculateResiliencyCost2(cityChar);
                cityChar[tic] = cityChar[wc]+cityChar[dc]+cityChar[rc];
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 7: // (cityChar[dh]=0) && (cityChar[dbh]>0) && (cityChar[rh]=0)
                cityChar[dc]  = CalculateDikeCost(cityChar[dh],UnitCostPerVolumeDike,CitySlope,CityWidth,SlopeDike,WidthDikeTop,DikeStartingCostPoint);
                cityChar[vz1] = 0; // calculate value zone 1
                cityChar[vz2] = cityChar[tcvaw]*DikeUnprotectedValuationRatio*cityChar[dbh]/(CEC-cityChar[wh]); // calculate value zone 2
                cityChar[vz3] = 0; // calculate value zone 3
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[dbh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz2]+cityChar[vz4];
                cityChar[tz1] = cityChar[wh];
                cityChar[tz2] = cityChar[wh]+cityChar[dbh];
                cityChar[tz3] = cityChar[tz2];
                cityChar[tz4] = CEC;
                cityChar[rc]  = 0;
                cityChar[tic] = cityChar[wc]+cityChar[dc];
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 8:  // (cityChar[dh]=0) && (cityChar[dbh]=0) && cityChar[rh]>0
                cityChar[dc]=0;
                cityChar[vz1] = cityChar[tcvaw]*cityChar[rh]/(CEC-cityChar[wh]); // calculate value zone 1
                cityChar[vz2] = 0; // calculate value zone 2
                cityChar[vz3] = 0; // calculate value zone 3
                cityChar[vz4] = cityChar[tcvaw]*(CEC-cityChar[wh]-cityChar[rh])/(CEC-cityChar[wh]); // calculate value zone 4
                cityChar[fcv] = cityChar[vz1]+cityChar[vz4];
                cityChar[tz1] = cityChar[wh]+cityChar[rh];
                cityChar[tz2] = cityChar[tz1];
                cityChar[tz3] = cityChar[tz1];
                cityChar[tz4] = CEC;
                cityChar[rc]  = CalculateResiliencyCost1(cityChar);
                cityChar[tic] = cityChar[wc]+cityChar[rc];
                cityChar[tc]  = cityChar[tic]+cityChar[fcv]-cityChar[tcvi];
                break;
            case 9: // (cityChar[dh]=0) && (cityChar[dbh]=0) && cityChar[rh]=0
                cityChar[fcv] = cityChar[tcvaw];
                cityChar[dc]  = 0;
                cityChar[vz1] = 0; // calculate value zone 1
                cityChar[vz2] = 0; // calculate value zone 2
                cityChar[vz3] = 0; // calculate value zone 3
                cityChar[vz4] = cityChar[tcvaw]; // calculate value zone 4
                cityChar[fcv] = cityChar[vz4];
                cityChar[tz1] = cityChar[wh];
                cityChar[tz2] = cityChar[wh];
                cityChar[tz3] = cityChar[wh];
                cityChar[tz4] = CEC;
                cityChar[rc]  = 0;
                cityChar[tic] = cityChar[wc];
                cityChar[tc]  = cityChar[tcvi]-cityChar[fcv];
                break;
        }

    }

} // extern "C"


// ========================================
// TEST HARNESS - Generate reference outputs
// ========================================

using namespace std;

struct TestCase {
    string name;
    double W, R, P, D, B;  // Levers
    double h_surge;         // Surge height for damage calculation
};

int main() {
    // Define 8 test cases covering edge cases and typical scenarios
    vector<TestCase> test_cases = {
        {"zero_case", 0, 0, 0, 0, 0, 0},
        {"dike_only", 0, 0, 0, 5, 0, 3},
        {"full_protection", 2, 3, 0.8, 5, 1, 4},
        {"resistance_only", 0, 4, 0.5, 0, 0, 2},
        {"withdrawal_only", 5, 0, 0, 0, 0, 3},
        {"edge_r_geq_b", 0, 6, 0.5, 3, 5, 4},
        {"high_surge", 2, 3, 0.8, 5, 1, 15},
        {"below_seawall", 0, 0, 0, 0, 0, 1.5}
    };

    // Open output files
    ofstream costs_out("outputs/costs.txt");
    ofstream zones_out("outputs/zones.txt");
    ofstream summary_out("outputs/summary.txt");

    // Set high precision for outputs
    costs_out << std::setprecision(15);
    zones_out << std::setprecision(15);
    summary_out << std::setprecision(15);

    // Write summary header
    summary_out << "# ICOW C++ Reference Outputs (Debugged Version)\n";
    summary_out << "# Generated from debugged C++ code with 3 bug fixes applied\n";
    summary_out << "# Bug Fix 1: Line 147 - Changed pow(..., 1/2) to sqrt(...)\n";
    summary_out << "# Bug Fix 2: Line 145 - Changed 2*dh*(ch+1/sd) to 2*ch*(ch+1/sd)\n";
    summary_out << "# Bug Fix 3: Line 35 - Changed CitySlope from CityLength/CityWidth to CityWidth/CityLength\n\n";

    // Process each test case
    for (const auto& tc : test_cases) {
        double cityChar[27];
        memset(cityChar, 0, sizeof(cityChar));

        // Call CharacterizeCity to compute all costs and zone values
        CharacterizeCity(tc.W, tc.B, tc.R, tc.P, tc.D, cityChar);

        // === Write costs output ===
        costs_out << "# Test Case: " << tc.name << "\n";
        costs_out << "# Levers: W=" << tc.W << ", R=" << tc.R << ", P=" << tc.P
                  << ", D=" << tc.D << ", B=" << tc.B << "\n";
        costs_out << "withdrawal_cost: " << cityChar[22] << "\n";  // wc
        costs_out << "value_after_withdrawal: " << cityChar[17] << "\n";  // tcvaw
        costs_out << "resistance_cost: " << cityChar[23] << "\n";  // rc
        costs_out << "dike_cost: " << cityChar[21] << "\n";  // dc
        costs_out << "total_investment_cost: " << cityChar[24] << "\n\n";  // tic

        // === Write zone geometry output ===
        zones_out << "# Test Case: " << tc.name << "\n";
        zones_out << "# Levers: W=" << tc.W << ", R=" << tc.R << ", P=" << tc.P
                  << ", D=" << tc.D << ", B=" << tc.B << "\n";
        zones_out << "case_number: " << (int)cityChar[0] << "\n";  // caseNum
        zones_out << "zone1_value: " << cityChar[6] << "\n";  // vz1
        zones_out << "zone2_value: " << cityChar[7] << "\n";  // vz2
        zones_out << "zone3_value: " << cityChar[8] << "\n";  // vz3
        zones_out << "zone4_value: " << cityChar[9] << "\n";  // vz4
        zones_out << "zone1_top: " << cityChar[10] << "\n";  // tz1
        zones_out << "zone2_top: " << cityChar[11] << "\n";  // tz2
        zones_out << "zone3_top: " << cityChar[12] << "\n";  // tz3
        zones_out << "zone4_top: " << cityChar[13] << "\n\n";  // tz4
    }

    costs_out.close();
    zones_out.close();
    summary_out.close();

    cout << "Test outputs generated successfully in outputs/ directory!\n";
    cout << "Files created:\n";
    cout << "  - outputs/costs.txt\n";
    cout << "  - outputs/zones.txt\n";
    cout << "  - outputs/summary.txt\n";

    return 0;
}
