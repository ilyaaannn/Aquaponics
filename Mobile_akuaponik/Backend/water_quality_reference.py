from dataclasses import dataclass
from typing import List, Optional

PH_IDEAL_MIN, PH_IDEAL_MAX = 6.5, 7.5
PH_DANGER_LOW, PH_DANGER_HIGH = 5.5, 8.5
TEMP_IDEAL_MIN, TEMP_IDEAL_MAX = 25.0, 30.0
TEMP_DANGER_LOW, TEMP_DANGER_HIGH = 20.0, 34.0
TDS_IDEAL_MIN, TDS_IDEAL_MAX = 0.0, 700.0
TDS_DANGER_MIN = 1300.0
DO_IDEAL_MIN = 6.0
DO_DANGER_MAX = 3.0

DANGER_NOTIFICATION_TITLE = "🚨 BAHAYA Kualitas Air Akuaponik!"
LABELS = {"pH": "pH", "Temp": "Suhu", "TDS": "TDS", "DO": "DO"}

@dataclass
class SensorIssue:
    param: str
    label: str
    value: float
    is_critical: bool
    solution: str
    short_detail: str

def is_out_of_range(param: str, value: float) -> bool:
    if param == "pH":
        return value < PH_IDEAL_MIN or value > PH_IDEAL_MAX
    if param == "Temp":
        return value < TEMP_IDEAL_MIN or value > TEMP_IDEAL_MAX
    if param == "TDS":
        return value < TDS_IDEAL_MIN or value > TDS_IDEAL_MAX
    if param == "DO":
        return value < DO_IDEAL_MIN 
    return False

def is_critical(param: str, value: float) -> bool:
    if param == "pH":
        return value < PH_DANGER_LOW or value > PH_DANGER_HIGH
    if param == "Temp":
        return value < TEMP_DANGER_LOW or value > TEMP_DANGER_HIGH
    if param == "TDS":
        return value > TDS_DANGER_MIN
    if param == "DO":
        return value < DO_DANGER_MAX 
    return False

def solution_for(param: str, value: float) -> str:
    """Teks solusi — SAMA dengan _getSensorSolution di dashboard Flutter
    (kini hidup di helper/water_quality_reference.dart)."""
    if param == "pH":
        if value < PH_DANGER_LOW:
            return ("pH sangat asam (bahaya) — tambahkan Ca(OH)2 atau "
                    "NaHCO3 secara bertahap, cek ulang setiap 2 jam.")
        if value > PH_DANGER_HIGH:
            return ("pH sangat basa (bahaya) — tambahkan asam sitrat "
                    "encer, pastikan aerasi cukup.")
        if value < PH_IDEAL_MIN:
            return ("pH sedikit rendah — tambahkan sedikit NaHCO3, "
                    "pantau respons tumbuhan.")
        if value > PH_IDEAL_MAX:
            return ("pH sedikit tinggi — batasi penambahan mineral, "
                    "ganti sebagian air (10–15%).")
        return ""

    if param == "Temp":
        if value < TEMP_DANGER_LOW:
            return "Suhu terlalu dingin (bahaya) — aktifkan heater, tutup greenhouse."
        if value > TEMP_DANGER_HIGH:
            return "Suhu kritis (bahaya) — tambah aerasi/oksigenasi, naungi kolam."
        if value < TEMP_IDEAL_MIN:
            return "Suhu rendah — ikan kurang aktif. Pantau DO, tambah aerasi jika perlu."
        if value > TEMP_IDEAL_MAX:
            return ("Suhu tinggi — DO cenderung turun. Tingkatkan aerasi, "
                    "hindari beri pakan siang hari.")
        return ""

    if param == "TDS":
        if value > TDS_DANGER_MIN:
            return "TDS sangat tinggi (bahaya) — ganti air 20–30%, kurangi pakan, periksa filter."
        if value > TDS_IDEAL_MAX:
            return "TDS tinggi — ganti sebagian air (10–15%), pastikan filtrasi berjalan baik."
        if value < TDS_IDEAL_MIN:
            return "Nutrisi terlalu encer — tambahkan pupuk akuaponik (Fe, K, Ca)."
        return ""

    if param == "DO":
        if value < DO_DANGER_MAX:
            return "DO kritis (bahaya) — aktifkan aerator penuh, hentikan pakan, kurangi kepadatan ikan!"
        if value < DO_IDEAL_MIN:
            return "DO rendah — tambah aerasi, kurangi beban organik, periksa pompa."
        return ""

    return ""

def evaluate_param(param: str, value: Optional[float]) -> Optional[SensorIssue]:
    if value is None or not is_out_of_range(param, value):
        return None
    label = LABELS.get(param, param)
    return SensorIssue(
        param=param,
        label=label,
        value=value,
        is_critical=is_critical(param, value),
        solution=solution_for(param, value),
        short_detail=f"{label} {value:.1f}",
    )

def evaluate_all(ph, temp, tds, do_val) -> List[SensorIssue]:
    """Urutan tetap: pH, Temp, TDS, DO — sama seperti versi Dart."""
    candidates = [
        evaluate_param("pH", ph),
        evaluate_param("Temp", temp),
        evaluate_param("TDS", tds),
        evaluate_param("DO", do_val),
    ]
    return [c for c in candidates if c is not None]

def danger_notification_body(critical_issues: List[SensorIssue], consecutive_readings: int) -> str:
    """Sama gaya bahasa dengan notif_body di app.py sebelumnya, tapi kini
    disusun dari satu sumber yang sama dengan tampilan Flutter."""
    if not critical_issues:
        return (f"Status kualitas air: BAHAYA selama "
                f"{consecutive_readings} pembacaan berturut-turut!")
    detail_parts = ", ".join(issue.short_detail for issue in critical_issues)
    return f"Parameter abnormal: {detail_parts}. Segera periksa ekosistem akuaponik Anda!"