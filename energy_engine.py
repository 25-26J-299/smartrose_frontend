import json

def decide_energy_actions(sensor_data: dict, stress_label: str) -> dict:
    """
    Energy Optimization Decision Engine (EODE) - PP1 Research Demo
    
    This function implements a heuristic decision layer for the Energy-Optimized 
    Stress Monitoring (EOSM) system. It balances plant physiological needs 
    (based on ML stress prediction) with electrical energy conservation.
    
    Logic Priorities:
    1. Actuator Balancing: Use low-power fans for cooling before high-power AC.
    2. Dehumidification: Prioritize AC/Fans during high humidity (>85%).
    3. Resource Protection: Avoid high irrigation during high humidity to prevent rot.
    4. Solar Management: Use passive shading to reduce active cooling requirements.
    """
    
    # Baseline Actuator States
    actions = {
        "fan_speed": "OFF",
        "ac_level": "OFF",
        "water_pump": "OFF",
        "uv_intensity": "OFF",
        "energy_mode": "OPTIMIZED"
    }

    # Input Data Extraction
    temp = sensor_data.get("temperature", 0)
    hum = sensor_data.get("humidity", 0)
    soil_v = sensor_data.get("soil_voltage", 0)
    uv_v = sensor_data.get("uv_voltage", 0)
    stress = stress_label.upper()

    # --- RULE 1: CLIMATE CONTROL (Thermal/Humidity Management) ---
    if stress == "HIGH" or stress == "MEDIUM":
        if temp > 30:
            actions["fan_speed"] = "HIGH"
            # Optimization: If temp is high but not extreme, keep AC at MEDIUM to save energy
            actions["ac_level"] = "MEDIUM" if temp < 33 else "HIGH"
        else:
            actions["fan_speed"] = "MEDIUM"
            actions["ac_level"] = "LOW"
            
    # --- RULE 2: DEHUMIDIFICATION OVERRIDE ---
    # High Humidity (>85%) requires active air movement to prevent fungal stress
    if hum > 85:
        actions["fan_speed"] = "HIGH"
        # AC is required for its dehumidification cycle
        if actions["ac_level"] == "OFF" or actions["ac_level"] == "LOW":
            actions["ac_level"] = "MEDIUM"

    # --- RULE 3: IRRIGATION (Soil Moisture Balancing) ---
    # Higher soil_voltage typically indicates drier soil
    if soil_v > 2.2:
        if hum > 85:
            # SAFETY RULE: Avoid HIGH water in HIGH humidity even if soil is dry
            # This prevents root rot and excessive greenhouse humidity
            actions["water_pump"] = "MEDIUM"
        else:
            actions["water_pump"] = "HIGH"
    elif soil_v > 1.8:
        actions["water_pump"] = "LOW"

    # --- RULE 4: SOLAR & LIGHTING (UV Management) ---
    # Shading (UV Intensity) is a passive way to cool without using AC
    if uv_v > 0.35:
        # High solar radiation detected; use Shading (Actuator = FULL/HIGH)
        actions["uv_intensity"] = "FULL" 
    elif stress == "LOW":
        actions["uv_intensity"] = "OFF"
    else:
        actions["uv_intensity"] = "MEDIUM"

    # --- RULE 5: MAX SAVING MODE ---
    # If stress is LOW and conditions are stable, minimize all power usage
    if stress == "LOW" and temp < 28 and hum < 75:
        actions["fan_speed"] = "LOW"
        actions["ac_level"] = "OFF"
        actions["water_pump"] = "OFF"
        actions["uv_intensity"] = "OFF"
        actions["energy_mode"] = "MAX_SAVING"

    return actions

if __name__ == "__main__":
    # Test Data: Based on your latest 31.4C, 91.2% humidity reading
    test_sensor_data = {
        "temperature": 31.4,
        "humidity": 91.2,
        "soil_voltage": 2.25,
        "uv_voltage": 0.38
    }
    
    test_stress_label = "HIGH"
    
    # Calculate recommended actions
    optimized_actions = decide_energy_actions(test_sensor_data, test_stress_label)
    
    # Format and Output Results
    print("\n" + "="*40)
    print(" EOSM ENERGY OPTIMIZATION OUTPUT")
    print("="*40)
    print(f"INPUT STRESS: {test_stress_label}")
    print(f"INPUT DATA  : T:{test_sensor_data['temperature']}C | H:{test_sensor_data['humidity']}%")
    print("-" * 40)
    print(json.dumps(optimized_actions, indent=2))
    print("="*40 + "\n")

