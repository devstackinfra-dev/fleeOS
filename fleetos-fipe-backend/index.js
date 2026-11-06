const fs = require('fs');

const HEADERS = {
  Host: 'veiculos.fipe.org.br',
  Referer: 'http://veiculos.fipe.org.br',
  'Content-Type': 'application/json'
};

const TIPO_CARRO = 1;

const OUTPUT_FILE = 'fleetos_catalog.json';
const CHECKPOINT_FILE = 'fleetos_checkpoint.json';

const sleep = (ms) =>
  new Promise(resolve => setTimeout(resolve, ms));

function loadJson(path, fallback = []) {
  try {
    if (fs.existsSync(path)) {
      return JSON.parse(
        fs.readFileSync(path, 'utf8')
      );
    }
  } catch (_) {}

  return fallback;
}

function saveJson(path, data) {
  fs.writeFileSync(
    path,
    JSON.stringify(data, null, 2)
  );
}

function normalizePrice(price) {
  if (!price) return 0;

  return Number(
    price
      .replace('R$', '')
      .replace(/\./g, '')
      .replace(',', '.')
      .trim()
  );
}

async function fetchFipe(endpoint, body = {}, retries = 5) {

  const url =
    `http://veiculos.fipe.org.br/api/veiculos/${endpoint}`;

  for (let tentativa = 1; tentativa <= retries; tentativa++) {

    const response = await fetch(url, {
      method: 'POST',
      headers: HEADERS,
      body: JSON.stringify(body)
    });

    if (response.ok) {
      return response.json();
    }

    if (response.status === 429) {

      const waitTime =
        tentativa * 120000;

      console.log(
        `⚠️ Rate Limit 429 - aguardando ${waitTime / 1000}s`
      );

      await sleep(waitTime);

      continue;
    }

    throw new Error(
      `HTTP ${response.status}`
    );
  }

  throw new Error(
    `Falha definitiva em ${endpoint}`
  );
}

function extractFamily(model) {

  const stopWords = [
    '1.0',
    '1.3',
    '1.4',
    '1.5',
    '1.6',
    '1.8',
    '2.0',
    '2.5'
  ];

  const words =
    model.trim().split(' ');

  const family = [];

  for (const word of words) {

    if (
      stopWords.includes(word) ||
      /^\d/.test(word)
    ) {
      break;
    }

    family.push(word);
  }

  return family.join(' ');
}

function getPropulsionType(fuel) {

  const text =
    (fuel || '').toLowerCase();

  if (text.includes('elétr'))
    return 'ELECTRIC';

  if (text.includes('híbr'))
    return 'HYBRID';

  if (text.includes('diesel'))
    return 'DIESEL';

  if (text.includes('gasolina'))
    return 'GASOLINE';

  return 'FLEX';
}

function getSegment(model) {

  const m =
    model.toLowerCase();

  if (
    m.includes('corolla') ||
    m.includes('cronos') ||
    m.includes('virtus') ||
    m.includes('sentra') ||
    m.includes('city') ||
    m.includes('king')
  ) {
    return 'SEDAN';
  }

  if (
    m.includes('tracker') ||
    m.includes('creta') ||
    m.includes('compass') ||
    m.includes('renegade') ||
    m.includes('haval')
  ) {
    return 'SUV';
  }

  if (
    m.includes('dolphin') ||
    m.includes('gol') ||
    m.includes('hb20') ||
    m.includes('c3') ||
    m.includes('argo') ||
    m.includes('mobi')
  ) {
    return 'HATCH';
  }

  return 'OTHER';
}

function getFleetCategory(model) {

  const m =
    model.toLowerCase();

  if (
    m.includes('gol') ||
    m.includes('mobi') ||
    m.includes('hb20') ||
    m.includes('c3')
  ) {
    return 'CAT-A';
  }

  if (
    m.includes('argo') ||
    m.includes('cronos') ||
    m.includes('virtus') ||
    m.includes('city')
  ) {
    return 'CAT-B';
  }

  if (
    m.includes('corolla') ||
    m.includes('sentra') ||
    m.includes('civic')
  ) {
    return 'CAT-C';
  }

  if (
    m.includes('king') ||
    m.includes('song') ||
    m.includes('haval')
  ) {
    return 'CAT-H';
  }

  if (
    m.includes('dolphin') ||
    m.includes('seal') ||
    m.includes('ora')
  ) {
    return 'CAT-E';
  }

  return 'CAT-A';
}

function getMaintenanceGroup(
  propulsionType,
  segment
) {

  if (
    propulsionType === 'ELECTRIC'
  ) {
    return 'electric';
  }

  if (
    propulsionType === 'HYBRID'
  ) {
    return 'hybrid';
  }

  if (
    segment === 'SUV'
  ) {
    return 'suv';
  }

  if (
    segment === 'SEDAN'
  ) {
    return 'sedan';
  }

  return 'economico';
}

async function run() {

  let catalog =
    loadJson(
      OUTPUT_FILE,
      []
    );

  let checkpoint =
    loadJson(
      CHECKPOINT_FILE,
      {}
    );

  console.log(
    '🚗 FleetOS Catalog Builder'
  );

  const tabelas =
    await fetchFipe(
      'ConsultarTabelaDeReferencia'
    );

  const codTabela =
    tabelas[0].Codigo;

  console.log(
    `📅 Tabela ${codTabela}`
  );

  const marcas =
    await fetchFipe(
      'ConsultarMarcas',
      {
        codigoTabelaReferencia:
          codTabela,
        codigoTipoVeiculo:
          TIPO_CARRO
      }
    );

  const marcasFleetOS = [

    'Toyota',
    'Volkswagen',
    'Fiat',
    'Chevrolet',
    'Hyundai',

    'Honda',
    'Renault',
    'Nissan',

    'Jeep',
    'BYD',

    'CAOA Chery',
    'GWM',

    'Citroën',
    'Peugeot',

    'Ford',
    'Mitsubishi',

    'RAM',
    'NETA',
    'JAC'
  ];

  const selecionadas =
    marcas.filter(
      m =>
        marcasFleetOS.includes(
          m.Label
        )
    );

  for (const marca of selecionadas) {

    if (
      checkpoint[marca.Label]
    ) {

      console.log(
        `⏭️ ${marca.Label} já processada`
      );

      continue;
    }

    console.log(
      `\n🏭 ${marca.Label}`
    );

    try {

      const modelosData =
        await fetchFipe(
          'ConsultarModelos',
          {
            codigoTabelaReferencia:
              codTabela,

            codigoTipoVeiculo:
              TIPO_CARRO,

            codigoMarca:
              marca.Value
          }
        );

      for (
        const modelo of modelosData.Modelos
      ) {

        const anos =
          await fetchFipe(
            'ConsultarAnoModelo',
            {
              codigoTabelaReferencia:
                codTabela,

              codigoTipoVeiculo:
                TIPO_CARRO,

              codigoMarca:
                marca.Value,

              codigoModelo:
                modelo.Value
            }
          );

        const anosValidos =
          anos.filter(a => {

            const ano =
              parseInt(
                a.Value.split('-')[0]
              );

            return ano >= 2016;

          });

        for (
          const ano of anosValidos
        ) {

          const jaExiste =
            catalog.some(
              c =>
                c.modelId ==
                  modelo.Value &&
                c.yearId ==
                  ano.Value
            );

          if (jaExiste) {
            continue;
          }

          const [anoModelo, tipoComb] =
            ano.Value.split('-');

          const veiculo =
            await fetchFipe(
              'ConsultarValorComTodosParametros',
              {
                codigoTabelaReferencia:
                  codTabela,

                codigoTipoVeiculo:
                  TIPO_CARRO,

                codigoMarca:
                  marca.Value,

                codigoModelo:
                  modelo.Value,

                ano:
                  ano.Value,

                codigoTipoCombustivel:
                  parseInt(tipoComb),

                anoModelo:
                  parseInt(anoModelo),

                tipoConsulta:
                  'tradicional'
              }
            );

          const propulsionType =
            getPropulsionType(
              veiculo.Combustivel
            );

          const segment =
            getSegment(
              veiculo.Modelo
            );

          catalog.push({

            brandId:
              marca.Value,

            brand:
              veiculo.Marca,

            family:
              extractFamily(
                veiculo.Modelo
              ),

            modelId:
              modelo.Value,

            model:
              veiculo.Modelo,

            yearId:
              ano.Value,

            year:
              veiculo.AnoModelo,

            fuelType:
              veiculo.Combustivel,

            propulsionType,

            segment,

            fleetCategory:
              getFleetCategory(
                veiculo.Modelo
              ),

            maintenanceGroup:
              getMaintenanceGroup(
                propulsionType,
                segment
              ),

            price:
              veiculo.Valor,

            priceValue:
              normalizePrice(
                veiculo.Valor
              ),

            fipeCode:
              veiculo.CodigoFipe,

            referenceMonth:
              veiculo.MesReferencia,

            active: true,

            createdAt:
              new Date()
                .toISOString()
          });

          saveJson(
            OUTPUT_FILE,
            catalog
          );

          console.log(
            `✅ ${veiculo.Modelo} (${veiculo.AnoModelo})`
          );

          await sleep(1000);
        }
      }

      checkpoint[
        marca.Label
      ] = true;

      saveJson(
        CHECKPOINT_FILE,
        checkpoint
      );

    } catch (err) {

      console.log(
        `❌ Erro em ${marca.Label}`
      );

      console.log(
        err.message
      );
    }
  }

  console.log(
    `\n🎉 Finalizado`
  );

  console.log(
    `🚗 Total: ${catalog.length}`
  );
}

run();