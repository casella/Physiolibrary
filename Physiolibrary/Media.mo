within Physiolibrary;
package Media
  extends Modelica.Icons.Package;
  package SimpleBodyFluid "Simplified Human body fluid"
    extends Modelica.Media.Interfaces.PartialMedium(
      final mediumName="SimpleBodyFluid (Physiolibrary)",
      final substanceNames={"Na","HCO3-","K","Glu","Urea","Cl","Ca","Mg","Alb",
    "Glb","Others","H2O"},
      final singleState=true,
      final reducedX=false,
      final fixedX=false,
      ThermoStates = Modelica.Media.Interfaces.Choices.IndependentVariables.pTX,
      reference_X = x_default,
      reference_T = 310.15,
      reference_p = 101325,
      Temperature(
        min=273,
        max=350,
        start=310.15));

  protected
    constant Modelica.Units.SI.Concentration
      concentrations_without_water_default[nCS - 1]={135,24,5,5,3,105,1.5,0.5,
        0.7,0.8,1e-6}
      "initial amounts of base molecules in mmol of substances per one liter [mmol/l]";

    constant Modelica.Units.SI.Volume water_volume=1 - (
        concentrations_without_water_default*stateOfMatter.molarVolume(
        substanceData[1:nCS - 1]));
    constant Modelica.Units.SI.AmountOfSubstance water_n=water_volume/
        stateOfMatter.molarVolume(substanceData[nCS]);

    constant Modelica.Units.SI.Concentration concentration_default[nCS]=cat(
        1,
        concentrations_without_water_default,
        {water_n});

    constant Modelica.Units.SI.MoleFraction x_default[nCS]=
        concentration_default ./ (concentration_default*ones(nCS))
      "initial mole fraction of substances";

    constant Modelica.Units.SI.MolarMass MM_default=x_default*
        stateOfMatter.molarMass(substanceData);

    constant Modelica.Units.SI.MolarVolume MV_default=x_default*
        stateOfMatter.molarVolume(substanceData);

    constant Modelica.Units.SI.Density density_default=MM_default/
        MV_default "initial density";

  public
    package stateOfMatter = Chemical.Interfaces.Incompressible
    "Substances model to translate data into substance properties";

    constant Integer nCS=nX "Number of chemical substances";

    constant stateOfMatter.SubstanceData substanceData[nS] = {
      Chemical.Substances.Sodium_aqueous(),
      Chemical.Substances.Bicarbonate_aqueous(),
      Chemical.Substances.Potassium_aqueous(),
      Chemical.Substances.Glucose_solid(),
      Chemical.Substances.Urea_aqueous(),
      Chemical.Substances.Chloride_aqueous(),
      Chemical.Substances.Calcium_aqueous(),
      Chemical.Substances.Magnesium_aqueous(),
      Chemical.Substances.Albumin_aqueous(),
      Chemical.Substances.Globulins_aqueous(),
      Chemical.Substances.Water_liquid_without_selfClustering(),
      Chemical.Substances.Water_liquid()}
       "Definition of the substances";

    replaceable model ChemicalSolution
      Chemical.Interfaces.SubstancePorts_a substances[nCS];
      input Modelica.Units.SI.Pressure p "pressure";
      input Modelica.Units.SI.SpecificEnthalpy h "specific enthalpy";
      input Modelica.Units.SI.MassFraction X[nCS] "mass fractions of substances";
      input Modelica.Units.SI.ElectricPotential v=0 "electric potential";
      input Modelica.Units.SI.MoleFraction I=0 "mole fraction based ionic strength";

      Modelica.Blocks.Interfaces.RealOutput molarFlows[nCS](each unit="mol/s") "molar flows of substances";
      Modelica.Blocks.Interfaces.RealOutput actualStreamMolarEnthalpies[nCS](each unit="J/mol")
        "molar enthalpies in streams";

      parameter Boolean EnthalpyNotUsed=false annotation (
        Evaluate=true,
        HideResult=true,
        choices(checkBox=true),
        Dialog(tab="Advanced", group="Performance"));

      Modelica.Blocks.Interfaces.RealOutput T "temperature";
    protected
      ThermodynamicState state=setState_phX(
            p,
            h,
            X);
    equation
      T = state.T;

      actualStreamMolarEnthalpies = if EnthalpyNotUsed then zeros(nCS) else actualStream(substances.h_outflow)
        "molar enthalpy in stream";

      substances.u = electrochemicalPotentials_pTXvI(
          p,
          T,
          X,
          v,
          I);

      substances.h_outflow = molarEnthalpies_pTvI(
          p,
          T,
          v,
          I);

      molarFlows = substances.q;
    end ChemicalSolution;

    redeclare model extends BaseProperties(final standardOrderComponents=true)
      "Base properties of medium"

    equation
      1/d = (X./stateOfMatter.molarMass(substanceData)) * stateOfMatter.molarVolume(substanceData,T=T,p=p);
      h = (X./stateOfMatter.molarMass(substanceData)) * stateOfMatter.molarEnthalpy(substanceData,T=T,p=p);
      u = h - p/d;
      MM = (ones(nCS)*X) / ((X./substanceData.MolarWeight) * ones(nCS));
      R_s = 8.3144/MM;
      state.p = p;
      state.T = T;
      state.X = X;
      state.v = 0;
    end BaseProperties;

    redeclare replaceable record ThermodynamicState
      "A selection of variables that uniquely defines the thermodynamic state"
      extends Modelica.Icons.Record;
      AbsolutePressure p "Absolute pressure of medium";
      Temperature T "Temperature of medium";
      Modelica.Units.SI.ElectricPotential v "Electric potential of medium";
      MassFraction X[nS] "Mass fractions of substances";
      annotation (Documentation(info="<html>

</html>"));
    end ThermodynamicState;

    replaceable function molarMasses
     output Modelica.Units.SI.MolarMass molarMasses[nCS];
    algorithm
      molarMasses := stateOfMatter.molarMass(substanceData);
    end molarMasses;

    redeclare function extends setState_pTX
      "Return thermodynamic state as function of p, T and composition X or Xi"
      input Modelica.Units.SI.ElectricPotential v=0;
    algorithm
      state.p :=p;
      state.T :=T;
      state.X :=X;
      state.v :=v;
    end setState_pTX;

   /* redeclare function extends setState_dTX
  algorithm 
    state.T :=T;
    state.X :=X;
  end setState_dTX;
*/
    redeclare function extends setState_phX
      "Return thermodynamic state as function of p, h and composition X or Xi"
      input Modelica.Units.SI.ElectricPotential v=0;
    protected
      MolarMass MM = (ones(nCS)*X) / ((X./substanceData.MolarWeight) * ones(nCS));
    algorithm
      state.p :=p;
      state.T := stateOfMatter.solution_temperature(substanceData,h*MM,X./stateOfMatter.molarMass(substanceData),p);
      state.X :=X;
      state.v :=v;
    end setState_phX;

    redeclare function extends dynamicViscosity "Return dynamic viscosity"
    algorithm
      eta := (2.414e-5)*10^(247.8/(state.T-140));  //https://www.engineersedge.com/physics/water__density_viscosity_specific_weight_13146.htm
      annotation (Documentation(info="<html>

</html>"));
    end dynamicViscosity;

    redeclare function extends thermalConductivity
      "Return thermal conductivity"
    algorithm
      lambda := 0.6; //google
      annotation (Documentation(info="<html>

</html>"));
    end thermalConductivity;

    redeclare function extends specificEnthalpy "Return specific enthalpy"
    algorithm
      h := stateOfMatter.molarEnthalpy(substanceData[1],T=state.T,p=state.p) / stateOfMatter.molarMass(substanceData[1]);
    end specificEnthalpy;


    redeclare function extends specificEntropy "Return specific entropy"
    protected
      Real a[nS] "activities of substances";
      Modelica.Units.SI.MolarEnergy u[nS]
        "electro-chemical potentials of substances in the solution";
    algorithm
      a := stateOfMatter.activityCoefficient(substanceData).*(state.X ./
        stateOfMatter.molarMass(substanceData)/(state.X*(ones(nS) ./
        stateOfMatter.molarMass(substanceData))));

      u := stateOfMatter.chemicalPotentialPure(
          substanceData,
          state.T,
          state.p,
          state.v) + Modelica.Constants.R*state.T*log(a) +
        stateOfMatter.chargeNumberOfIon(substanceData)*Modelica.Constants.F*state.v;

      s := (state.X ./ stateOfMatter.molarMass(substanceData)) * stateOfMatter.molarEntropy(u,substanceData,T=state.T,p=state.p);
      annotation (Documentation(info="<html>

</html>"));
    end specificEntropy;

    redeclare function extends specificHeatCapacityCp
      "Return specific heat capacity at constant pressure"
    algorithm
      cp := (state.X ./ stateOfMatter.molarMass(substanceData)) * stateOfMatter.molarHeatCapacityCp(substanceData,T=state.T,p=state.p);
      annotation (Documentation(info="<html>

</html>"));
    end specificHeatCapacityCp;

    redeclare function extends specificHeatCapacityCv
      "Return specific heat capacity at constant volume"
    algorithm
      cv := (state.X ./ stateOfMatter.molarMass(substanceData)) * stateOfMatter.molarHeatCapacityCv(substanceData,T=state.T,p=state.p);
      annotation (Documentation(info="<html>

</html>"));
    end specificHeatCapacityCv;

    redeclare function extends isentropicExponent "Return isentropic exponent"
      extends Modelica.Icons.Function;
    algorithm
      gamma := 23128; //http://twt.mpei.ac.ru/MCS/Worksheets/WSP/WKDiag15.xmcd
      annotation (Documentation(info="<html>

</html>"));
    end isentropicExponent;

    redeclare function extends velocityOfSound "Return velocity of sound"
      extends Modelica.Icons.Function;
    algorithm
      a := 1481; //wikipedia
      annotation (Documentation(info="<html>

</html>"));
    end velocityOfSound;

    redeclare function extends density
    algorithm
      d := (state.X*stateOfMatter.molarMass(substanceData)) / (state.X*stateOfMatter.molarVolume(substanceData));
    end density;

    redeclare function extends temperature
    algorithm
      T := state.T;
    end temperature;

    redeclare function extends pressure
    algorithm
      p := state.p;
    end pressure;

    replaceable function electrochemicalPotentials_pTXvI
      input Modelica.Units.SI.Pressure p;
      input Modelica.Units.SI.Temperature T;
      input Modelica.Units.SI.MassFraction X[nCS];
      input Modelica.Units.SI.ElectricPotential electricPotential=0;
      input Modelica.Units.SI.MoleFraction moleFractionBasedIonicStrength=0;
      output Modelica.Units.SI.ChemicalPotential u[nCS];
    protected
      parameter Modelica.Units.SI.MolarMass MM[nCS]=stateOfMatter.molarMass(
           substanceData);
      Real a[nCS];
      Modelica.Units.SI.ChargeNumberOfIon z[nCS];
    algorithm
      a := stateOfMatter.activityCoefficient(substanceData, T, p, electricPotential, moleFractionBasedIonicStrength) .*
        (((X ./ MM)) / ((X ./ MM) * ones(nCS)));
      z := stateOfMatter.chargeNumberOfIon(substanceData, T, p, electricPotential, moleFractionBasedIonicStrength);
      u:= stateOfMatter.chemicalPotentialPure(substanceData, T, p, electricPotential, moleFractionBasedIonicStrength)
         .+ Modelica.Constants.R*T*log(a)
         .+ z*Modelica.Constants.F*electricPotential;
    end electrochemicalPotentials_pTXvI;

    replaceable function molarEnthalpies_pTvI
      input Modelica.Units.SI.Pressure p;
      input Modelica.Units.SI.Temperature T;
      input Modelica.Units.SI.ElectricPotential electricPotential=0;
      input Modelica.Units.SI.MoleFraction moleFractionBasedIonicStrength=0;
      output Modelica.Units.SI.MolarEnthalpy h[nCS];
    algorithm
      h:= stateOfMatter.molarEnthalpy(
          substanceData, T, p, electricPotential, moleFractionBasedIonicStrength);
    end molarEnthalpies_pTvI;

    function C_outflow
      input Modelica.Units.SI.MassFraction x_mass[nCS];
     output Real C_outflow[nC];
    algorithm
      C_outflow := C_default;
      annotation(Inline=true);
    end C_outflow;

    function Xi_outflow
      input Modelica.Units.SI.MassFraction x_mass[nCS];
      output Modelica.Units.SI.MassFraction Xi[nXi];
    algorithm
      Xi := x_mass[1:nXi];
      annotation(Inline=true);
    end Xi_outflow;

    function x_mass
      input Modelica.Units.SI.MassFraction actualStream_Xi[nXi];
      input Real actualStream_C[nC];
      output Modelica.Units.SI.MassFraction x_mass[nCS];
    algorithm
      x_mass := actualStream_Xi;
      annotation(Inline=true);
    end x_mass;

    function concentration "Concentration of substances from Xi and C"
      input ThermodynamicState state;
      input Modelica.Units.SI.MassFraction Xi[nXi];
      input Real C[nC];
      output Modelica.Units.SI.Concentration concentration[nCS];
    algorithm
      concentration := Xi*density(state)./stateOfMatter.molarMass(substanceData);
    end concentration;

    function specificEnthalpyOffsets "Difference between chemical substance enthalpy and medium substance enthalpy at temperature 298.15 K and 100kPa"
      input Modelica.Units.SI.ElectricPotential v=0;
      input Real I=0;
      output SpecificEnthalpy h[nCS];
    algorithm
      h := zeros(nCS);
    end specificEnthalpyOffsets;


  end SimpleBodyFluid;

  package BloodBySiggaardAndersen
    "Blood for gases transport"
    extends Chemical.Media.Water_Incompressible(
      nCS=12,
      extraPropertiesNames={"RBC",    "O2",   "CO2",    "CO",   "Hb","MetHb","HbF","Alb","Glb", "PO4","DPG","SID"},
      C_default =           {0.44, 8.16865, 21.2679, 1.512e-6,   8.4, 0.042, 0.042, 0.66, 28, 0.153, 5.4, 37.67});

    redeclare model ChemicalSolution
      Chemical.Interfaces.SubstancePorts_a substances[nCS]
        annotation (Placement(transformation(extent={{-110,-42},{-90,38}})));
      input Modelica.Units.SI.Pressure p "pressure";
      input Modelica.Units.SI.SpecificEnthalpy h "specific enthalpy";
      input Modelica.Units.SI.MassFraction X[nCS] "mass fractions of substances";
      input Modelica.Units.SI.ElectricPotential v=0 "electric potential";
      input Modelica.Units.SI.MoleFraction I=0 "mole fraction based ionic strength";

      Modelica.Blocks.Interfaces.RealOutput molarFlows[nCS](each unit="mol/s") "molar flows of substances";
      Modelica.Blocks.Interfaces.RealOutput actualStreamMolarEnthalpies[nCS](each unit="J/mol")
        "molar enthalpies in streams";

      parameter Boolean EnthalpyNotUsed=false annotation (
        Evaluate=true,
        HideResult=true,
        choices(checkBox=true),
        Dialog(tab="Advanced", group="Performance"));

      Modelica.Blocks.Interfaces.RealOutput T "temperature";

    protected
      Real C[nCS] = (X ./ molarMasses()) .*  density_pTX(p,T,X);

      ThermodynamicState state;
      BloodGases bloodGases(p=p,T=310.15,C=C);
      Modelica.Units.SI.MoleFraction aO2,aCO2,aCO;
      Modelica.Units.SI.ChemicalPotential uO2,uCO2,uCO;
      constant Chemical.Interfaces.IdealGas.SubstanceData O2=Chemical.Substances.Oxygen_gas();
      constant Chemical.Interfaces.IdealGas.SubstanceData CO2=Chemical.Substances.CarbonDioxide_gas();
      constant Chemical.Interfaces.IdealGas.SubstanceData CO=Chemical.Substances.CarbonMonoxide_gas();

    equation
      if (EnthalpyNotUsed) then
        state = setState_pTX(p,T,X);
        T=310.15;
      else
        state = setState_phX(p,h,X);
        T=state.T;
      end if;

      actualStreamMolarEnthalpies = if EnthalpyNotUsed then zeros(nCS) else actualStream(substances.h_outflow)
        "molar enthalpy in stream";

      aO2 = bloodGases.pO2/p;
      aCO2 = bloodGases.pCO2/p;
      aCO = bloodGases.pCO/p;

      uO2 = Modelica.Constants.R*T*log(aO2)
            + Chemical.Interfaces.IdealGas.electroChemicalPotentialPure(O2,T,p,v,I);
      uCO2 = Modelica.Constants.R*T*log(aCO2)
            + Chemical.Interfaces.IdealGas.electroChemicalPotentialPure(CO2,T,p,v,I);
      uCO = Modelica.Constants.R*T*log(aCO)
            + Chemical.Interfaces.IdealGas.electroChemicalPotentialPure(CO,T,p,v,I);

      substances.u = {0,  uO2, uCO2,  uCO,   0,  0,    0,   0,  0,    0,    0,   0};

      substances.h_outflow = zeros(nCS);

      molarFlows = substances.q;
    end ChemicalSolution;

    redeclare function molarMasses
     output Modelica.Units.SI.MolarMass molarMasses[nCS];
    algorithm
                      // "RBC",  "O2", "CO2",  "CO",     "Hb",   "MetHb",    "HbF",  "Alb", "Glb", "PO4", "DPG", "SID"},
      molarMasses :=    { 1098, 0.032, 0.044, 0.059, 65.494/4,  65.494/4, 65.494/4, 66.463,     1, 0.095, 0.266, 0.031}
        "1. density of red cells; 
       2.-8. and 10.-11. molar masses of substances;
       9. conversion from g/L to kg/m3 for globulins;
       12. average molar mass of strong ions";

    end molarMasses;

    model BloodGases
        input Real C[12]=
        {0.44, 8.16865, 21.2679, 1.512e-6,   8.4, 0.042, 0.042, 0.66, 28, 0.153, 5.4, 37.67}
        "Volume, amount of substance or mass of substance per total volume of solution";

        input Modelica.Units.SI.Pressure p = 101325 "Pressure";
        input Modelica.Units.SI.Temperature T = 310.15 "Temperature";
        input Modelica.Units.SI.ElectricPotential electricPotential=0 "Electric potential";
        input Modelica.Units.SI.MoleFraction moleFractionBasedIonicStrength=0 "Mole-fraction based ionic strength";
        output Modelica.Units.SI.Pressure pO2(start = 101325*87/760) "Oxygen partial pressure";
        output Modelica.Units.SI.Pressure pCO2(start = 101325*40/760) "Carbon dioxide partial pressure";
        output Modelica.Units.SI.Pressure pCO(start = 1e-5) "Carbon monoxide partial pressure";

    protected
        Physiolibrary.Types.VolumeFraction Hct=C[1] "haematocrit";
        Physiolibrary.Types.Concentration tO2=C[2] "oxygen content per volume of blood",
             tCO2=C[3] "carbon dioxide content per volume of blood",
             tCO=C[4] "carbon monoxide content per volume of blood",
             tHb=C[5] "haemoglobin content per volume of blood";
        Physiolibrary.Types.MoleFraction  FMetHb=C[6]/C[5] "fraction of metheamoglobin",
             FHbF=C[7]/C[5] "fraction of foetalheamoglobin";
        Physiolibrary.Types.Concentration  ctHb_ery=C[5]/C[1] "haemoglobin concentration in red cells",
             tAlb=C[8] "albumin concentration in blood plasma";
        Physiolibrary.Types.MassConcentration tGlb=C[9] "globulin concentration in blood plasma";
        Physiolibrary.Types.Concentration tPO4=C[10] "inorganic phosphates concentration in blood plasma",
             cDPG=C[11] "DPG concentration in blood plasma",
             SID=C[12] "strong ion difference of blood";

        constant Physiolibrary.Types.Temperature T0 = 273.15+37 "normal temperature";
        constant Physiolibrary.Types.pH pH0 = 7.4 "normal pH";
        constant Physiolibrary.Types.pH pH_ery0 = 7.19 "normal pH in erythrocyte";
        constant Physiolibrary.Types.Pressure pCO20 = (40/760)*101325 "normal CO2 partial pressure";

        Physiolibrary.Types.Concentration NSIDP, NSIDE, NSID, BEox, cdCO2;
        Physiolibrary.Types.pH pH,pH_ery;

        Physiolibrary.Types.GasSolubilityPa aCO2N = 0.00023 "solubility of CO2 in blood plasma at 37 degC";
        Physiolibrary.Types.GasSolubilityPa aCO2 = 0.00023 * 10^(-0.0092*(T-310.15)) "solubility of CO2 in blood plasma";
        Physiolibrary.Types.GasSolubilityPa aCO2_ery( displayUnit="mmol/l/mmHg")=0.000195 "solubility 0.23 (mmol/l)/kPa at 25degC";
        Physiolibrary.Types.GasSolubilityPa aO2= exp(log(0.0105) + (-0.0115*(T - T0)) + 0.5*0.00042*(T - T0)^2)/1000
                                                                          "oxygen solubility in blood";
        Physiolibrary.Types.GasSolubilityPa aCO=(0.00099/0.0013)*aO2 "carbon monoxide solubility in blood";

        Real pK = 6.1 + (-0.0026)*(T-310.15) "Henderson-Hasselbalch";
        Real pK_ery = 6.125 - log10(1+10^(pH_ery-7.84-0.06*sO2));

        parameter Real pKa1=2.1, pKa2=6.8, pKa3=12.7 "H2PO4 dissociation";

        parameter Real betaOxyHb = 3.1 "buffer value for oxygenated Hb without CO2";
        parameter Real pIo=7.13  "isoelectric pH for oxygenated Hb without CO2";

        parameter Real pKzD=7.73 "pKa for NH3+ end of deoxygenated haemoglobin chain";
        parameter Real pKzO=7.25 "pKa for NH3+ end of oxygenated haemoglobin chain";
        parameter Real pKcD=7.54 "10^(pH-pKcR) is the dissociation constatnt for HbNH2 + CO2 <-> HbNHCOO- + H+ ";
        parameter Real pKcO=8.35 "10^(pH-pKcO) is the dissociation constatnt for O2HbNH2 + CO2 <-> O2HbNHCOO- + H+ ";
        parameter Real pKhD=7.52 "10^(pH-pKhD) is the dissociation constatnt for HbAH <-> HbA- + H+ ";
        parameter Real pKhO=6.89 "10^(pH-pKhO) is the dissociation constatnt for O2HbAH <-> O2HbA- + H+ ";

       Physiolibrary.Types.Concentration cdCO2N;
       Physiolibrary.Types.Fraction sCO2N,fzcON;

      Physiolibrary.Types.Concentration beta, cHCO3(start=24.524);

      Physiolibrary.Types.Fraction sO2CO(start=0.962774);
      Physiolibrary.Types.Fraction sCO(start=1.8089495e-07), sO2, FCOHb;
      Physiolibrary.Types.Concentration ceHb "effective hemoglobin";

      Physiolibrary.Types.Concentration tCO2_P( displayUnit="mmol/l");
      Physiolibrary.Types.Concentration tCO2_ery( displayUnit="mmol/l");

    equation
        cdCO2N = aCO2N * pCO20 "free disolved CO2 concentration at pCO2=40mmHg and T=37degC";

        NSIDP = -(tAlb*66.463)*( 0.123 * pH0 - 0.631)
                - tGlb*(2.5/28)
                - tPO4*(10^(pKa2-pH0)+2+3*10^(pH0-pKa3))/(10^(pKa1+pKa2-2*pH0)+10^(pKa2-pH0)+1+10^(pH0-pKa3))
                - cdCO2N*10^(pH0-pK) "strong ion difference of blood plasma at pH=7.4, pCO2=40mmHg, T=37degC and sO2=1";

        fzcON = 1/(1+ 10^(pKzO-pH_ery0) + cdCO2N * 10^(pH_ery0-pKcO)) "fraction of heamoglobin units with HN2 form of amino-terminus at pH=7.4 (pH_ery=7.19), pCO2=40mmHg, T=37degC and sO2=1";
        sCO2N = 10^(pH_ery0-pKcO) * fzcON * cdCO2N "CO2 saturation of hemoglobin amino-termini at pH=7.4 (pH_ery=7.19), pCO2=40mmHg, T=37degC and sO2=1";
        NSIDE = - cdCO2N*10^(pH_ery0-pK)
                - ctHb_ery*(betaOxyHb * (pH_ery0-pIo) +  sCO2N*(1+2*10^(pKzO-pH_ery0))/(1+10^(pKzO-pH_ery0)) + 0.82)
                "strong ion difference of red cells at pH=7.4 (pH_ery=7.19), pCO2=40mmHg, T=37degC and sO2=1";

        NSID = Hct * NSIDE + (1-Hct) * NSIDP "strong ion difference of blood at pH=7.4 (pH_ery=7.19), pCO2=40mmHg, T=37degC and sO2=1";

        BEox = (-SID) - NSID "base excess of oxygenated blood";

        beta = 2.3*tHb + 8*tAlb + 0.075*tGlb + 0.309*tPO4 "buffer value of blood";

        pH = pH0 + (1/beta)*(((BEox + 0.3*(1-sO2CO))/(1-tHb/43)) - (cHCO3-24.5)) "Van Slyke";
        pH_ery = 7.19 + 0.77*(pH-7.4) + 0.035*(1-sO2);

        sO2CO = getsO2CO( pH, pO2, pCO2, pCO, T, tHb,cDPG, FMetHb, FHbF);

        sCO*(pO2 + 218*pCO)= 218*sO2CO* (pCO);
        FCOHb= sCO*(1-FMetHb);
        tCO = aCO*pCO + FCOHb*tHb;

        ceHb =  tHb * (1-FCOHb-FMetHb);
        sO2 = (sO2CO*(tHb*(1-FMetHb)) - tHb*FCOHb)/ceHb;
        tO2 = aO2*pO2 + ceHb*sO2;

      cdCO2 = aCO2*pCO2;
      cdCO2 * 10^(pH-pK) = cHCO3;

      tCO2_P = cHCO3 + cdCO2;
      tCO2_ery=aCO2_ery*pCO2*(1+10^(pH_ery-pK_ery));
      tCO2 = tCO2_ery*Hct + tCO2_P*(1-Hct);

      annotation (Icon(coordinateSystem(preserveAspectRatio=false)), Diagram(coordinateSystem(
              preserveAspectRatio=false)));
    end BloodGases;

    function getsO2CO
        input Real pH, pO2, pCO2, pCO, T, tHb, cDPG, FMetHb, FHbF;
        output Real sO2CO;
    protected
       constant Physiolibrary.Types.Temperature T0 = 273.15+37 "normal temperature";
        constant Physiolibrary.Types.pH pH0 = 7.4 "normal pH";
        constant Physiolibrary.Types.pH pH_ery0 = 7.19 "normal pH in erythrocyte";
        constant Physiolibrary.Types.Pressure pCO20 = (40/760)*101325 "normal CO2 partial pressure";

        parameter Physiolibrary.Types.Concentration cDPG0 = 5
        "normal DPG,used by a";
        parameter Real dadcDPG0 = 0.3 "used by a";
        parameter Real dadcDPGxHbF = -0.1 "or perhabs -0.125";
        parameter Real dadpH = -0.88 "used by a";
        parameter Real dadlnpCO2 = 0.048 "used by a";
        parameter Real dadxMetHb = -0.7 "used by a";
        parameter Real dadxHbF = -0.25 "used by a";

        Real aO2, cdO2;
        Physiolibrary.Types.Fraction sO2;
        Physiolibrary.Types.Pressure pO2CO;
        Physiolibrary.Types.Concentration cO2Hb;
        Physiolibrary.Types.Fraction sCO;
        Physiolibrary.Types.Concentration ceHb;
        Real a;
        Real k;
        Real x;
        Real y;
        Real h;
        Physiolibrary.Types.Fraction FCOHb;
    algorithm

        a:=dadpH*(pH-pH0)+dadlnpCO2*log(max(1e-15+1e-22*pCO2,pCO2/pCO20)) +dadxMetHb*FMetHb+(dadcDPG0 + dadcDPGxHbF*FHbF)*(cDPG/cDPG0 - 1);
        k:=0.5342857;
        h:=3.5 + a;

        pO2CO:= pO2 + 218*pCO;
        x:=log(pO2CO/7000) - a - 0.055*(T-T0);
        y:=1.8747+x+h*tanh(k*x);

        sO2CO:= exp(y)/(1+exp(y));

    end getsO2CO;
    annotation (Documentation(info="<html>
<p>
This package is a <strong>template</strong> for <strong>new medium</strong> models. For a new
medium model just make a copy of this package, remove the
\"partial\" keyword from the package and provide
the information that is requested in the comments of the
Modelica source.
</p>
</html>"));
  end BloodBySiggaardAndersen;
end Media;
