# DCH Elo IDS Monitor Plugin

Plugin Q-SYS para controle de monitores Elo IDS via protocolo MDC.

## Recursos

- Power/backlight on/off
- Seleção de entrada: HDMI 1, HDMI 2, DisplayPort, USB-C, Side HDMI, ECM HDMI, ECM DP e VGA
- Volume absoluto e ajuste +/- 1%
- Brilho e contraste
- Touch on/off
- Leitura de temperatura interna e horas de uso
- Auto-adjust e recall defaults

## Conexão

O plugin envia frames MDC binários por TCP. Configure `IP Address` e `TCP Port` nas propriedades ou nos controles do plugin. Para o Elo IDS-4304L PCAP AF testado em rede, a porta MDC over TCP/IP aberta é `5000`.

Para monitores Elo IDS 03/53 por serial/USB virtual, a documentação da Elo informa MDC em `9600/8-N-1`. Para IDS 04/54 por TCP/IP, confirme que o firmware e as opções de MDC over TCP/IP estão habilitados no monitor. Em alguns modelos, Energy Saving Mode deve ficar desabilitado para comandos MDC funcionarem corretamente.

## Comandos MDC usados

- `0xD6`: power/backlight
- `0x60`: input source
- `0x61`: volume step
- `0x62`: volume absoluto
- `0x10`: brightness
- `0x12`: contrast
- `0xC7`: touch
- `0xB1`: temperatura
- `0xC0`: lifetime
- `0x04`: recall defaults
- `0x1E`: auto-adjust

## Build

O projeto mantém a estrutura do template Q-SYS com `plugin.lua` e includes Lua separados. O artefato expandido gerado nesta pasta é:

```text
DCH-ELO_Display_Plugin.qplug
```

No Windows, a task do VS Code ainda pode usar `plugincompile/PLUGCC.exe`. No macOS, o `.exe` incluído não roda diretamente sem o runtime/config .NET esperado, então o artefato atual foi gerado por expansão dos includes.
