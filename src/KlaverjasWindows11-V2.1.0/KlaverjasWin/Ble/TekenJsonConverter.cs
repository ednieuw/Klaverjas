using System.Text.Json;
using System.Text.Json.Serialization;

namespace Klaverjas.Ble;

/// <summary>
/// Een kaartnaam is op de Mac geen tekst maar een object met één veld:
/// <c>struct Teken { var raw: UInt8 }</c>, dat Swift's Codable daardoor codeert
/// als <c>{"raw": 65}</c> — niet als kaal getal of tekst. `raw` is de
/// ASCII-waarde van het rangteken ('A','H','V','B','T','9','8','7', of 0 voor
/// leeg), dezelfde waarden als de bestaande C#-engine al gebruikt als
/// <c>char</c>. Deze converter leest en schrijft dus een <c>char</c>, maar in
/// de JSON-vorm die de Mac-kant verwacht.
///
/// Getoetst tegen de drie voorbeelden in BLUETOOTH-VOOR-WINDOWS.md.
/// </summary>
public sealed class TekenJsonConverter : JsonConverter<char>
{
    public override char Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.StartObject)
            throw new JsonException("Verwacht een Teken-object ({\"raw\": N}), geen kale tekst of getal.");

        byte raw = 0;
        bool gevonden = false;
        while (reader.Read())
        {
            if (reader.TokenType == JsonTokenType.EndObject) break;
            if (reader.TokenType != JsonTokenType.PropertyName) continue;

            string naam = reader.GetString() ?? "";
            reader.Read();
            if (naam == "raw")
            {
                raw = reader.GetByte();
                gevonden = true;
            }
            else
            {
                reader.Skip();
            }
        }

        if (!gevonden) throw new JsonException("Teken-object zonder 'raw'-veld.");
        return (char)raw;
    }

    public override void Write(Utf8JsonWriter writer, char value, JsonSerializerOptions options)
    {
        writer.WriteStartObject();
        writer.WriteNumber("raw", (byte)value);
        writer.WriteEndObject();
    }
}
