# MaRVin SoC

Um SoC usando uma versao de CPU baseada no femtoRV32.
A ideia é futuramente utilizar a minha versão da maRVin CPU, sendo desenvolvida em projeto separado.
Por enquanto vou usando a atual para poder ir avançando o SoC

## TODO

* Serial
* Revisar e trocar comentários de portugues para ingles
* Verificar se precisamos de mais comentários em marvin.ld, crt0.S, marvin.v e marvin_gpio.v

## History
* First commit - Soc com CPU e memória
* Toolchain para compilar risc-v e exemplo em asm + tool bin2hex
* Compilando C e startup file : crt0.S
* GPIO (output)
* GPIO (input)
