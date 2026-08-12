# Pravidla pro R8 (zmenšování a obfuskace release buildu).

# ML Kit pro rozpoznávání textu umí pět písem a plugin
# google_mlkit_text_recognition na všechna odkazuje z jediné metody.
# Do aplikace se ale linkuje jen latinka – viz OcrSluzba, která vytváří
# TextRecognizer(script: TextRecognitionScript.latin) – takže třídy
# ostatních písem v APK nejsou a R8 build zastaví na chybějících
# referencích.
#
# Doplnit chybějící knihovny by APK zvětšilo o modely pro písma, která
# na počítadle nabíječky ani na štítku elektroměru nikdy nebudou. Proto
# se místo toho potlačí varování.
#
# Kdyby aplikace někdy měla číst i jiné písmo, tahle pravidla se musí
# zrušit a přidat odpovídající závislost – jinak spadne až za běhu.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
