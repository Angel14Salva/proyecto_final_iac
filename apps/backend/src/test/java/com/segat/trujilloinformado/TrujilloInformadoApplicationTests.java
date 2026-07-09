package com.segat.trujilloinformado;

import com.segat.trujilloinformado.integration.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class TrujilloInformadoApplicationTests extends AbstractIntegrationTest {

    @Test
    void contextLoads() {
    }

    @Test
    void dataSeederPoblaZonasYUsuariosAlArrancar() {
        assertThat(zonaDao.count()).isGreaterThan(0);
        assertThat(usuarioDao.count()).isGreaterThan(0);
    }

}
