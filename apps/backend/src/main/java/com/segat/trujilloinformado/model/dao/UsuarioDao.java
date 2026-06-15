package com.segat.trujilloinformado.model.dao;

import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.model.entity.enums.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface UsuarioDao extends JpaRepository<Usuario, Long> {
    Boolean existsByEmail(String email);
    Optional<Usuario> findByEmail(String email);

    /**
     * Reemplaza tu método findByZoneNumber con este.
     * Busca un usuario por el NÚMERO de su zona Y su ROL.
     * Asumiendo que tu campo en Usuario se llama 'zone' y dentro de Zone hay 'number'
     * y tu campo de rol se llama 'rol'.
     */
    Optional<Usuario> findByZone_NumberAndRole(Integer zoneNumber, Role role);

    @Query("select u from Usuario u where u.zone.number = :number and u.role = com.segat.trujilloinformado.model.entity.enums.Role.TRABAJADOR")
    List<Usuario> findTrabajadoresByZoneNumber(@Param("number") Integer number);

    @Query("select u from Usuario u left join fetch u.zone where u.email = :email")
    Optional<Usuario> findByEmailWithZone(@Param("email") String email);
}
