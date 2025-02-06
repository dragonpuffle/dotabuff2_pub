--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2024-12-17 03:52:17

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 16420)
-- Name: add_user_to_table(character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_user_to_table(_username character varying, _user_password text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.users WHERE username = _username) THEN
        RETURN 'Error: User already exists';
    ELSE
        INSERT INTO public.users (username, user_password)
        VALUES (_username, _user_password);
        RETURN 'User added successfully';
    END IF;
END;
$$;


ALTER FUNCTION public.add_user_to_table(_username character varying, _user_password text) OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 25260)
-- Name: clear_all_tables(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.clear_all_tables(schema_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    table_name TEXT;
BEGIN
    FOR table_name IN 
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = schema_name
    LOOP
        EXECUTE FORMAT('TRUNCATE TABLE %I.%I CASCADE;', schema_name, table_name);
    END LOOP;
END;
$$;


ALTER FUNCTION public.clear_all_tables(schema_name character varying) OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 25247)
-- Name: clear_table(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.clear_table(schema_name character varying, table_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE FORMAT('DELETE FROM %I.%I', schema_name, table_name);
END;
$$;


ALTER FUNCTION public.clear_table(schema_name character varying, table_name character varying) OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 16487)
-- Name: copy_tables_with_data(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.copy_tables_with_data(user_schema character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    tbl_name TEXT;
    serial_column TEXT;
    sequence_name TEXT;
BEGIN
    FOR tbl_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    LOOP
        EXECUTE FORMAT(
            'CREATE TABLE %I.%I (LIKE public.%I INCLUDING ALL);', 
            user_schema, tbl_name, tbl_name
        );

        EXECUTE FORMAT(
            'INSERT INTO %I.%I SELECT * FROM public.%I;', 
            user_schema, tbl_name, tbl_name
        );
    END LOOP;
END;
$$;


ALTER FUNCTION public.copy_tables_with_data(user_schema character varying) OWNER TO postgres;

--
-- TOC entry 239 (class 1255 OID 16422)
-- Name: create_abilities_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_abilities_table() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'abilities') THEN
        CREATE TABLE public.abilities (
            id SERIAL PRIMARY KEY,
            hero_id INT REFERENCES public.heroes(id) ON DELETE CASCADE,
            name VARCHAR(100) NOT NULL,
            description TEXT,
			type ARCHAR(50)
        );
    END IF;
END;
$$;


ALTER FUNCTION public.create_abilities_table() OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 16489)
-- Name: create_build_cost_trigger(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_build_cost_trigger(schema_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE FORMAT(
        'CREATE TRIGGER update_build_cost
         AFTER INSERT OR DELETE ON %I.build_items
         FOR EACH ROW
         EXECUTE FUNCTION recalculate_build_cost();',
        schema_name
    );
END;
$$;


ALTER FUNCTION public.create_build_cost_trigger(schema_name character varying) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 16425)
-- Name: create_build_items_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_build_items_table() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'build_items') THEN
        CREATE TABLE public.build_items (
            build_id INT REFERENCES public.builds(id) ON DELETE CASCADE,
            item_id INT REFERENCES public.items(id) ON DELETE CASCADE,
            PRIMARY KEY (build_id, item_id)
        );
    END IF;
END;
$$;


ALTER FUNCTION public.create_build_items_table() OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 24699)
-- Name: create_build_reviews_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_build_reviews_table() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'build_reviews'
    ) THEN
        CREATE TABLE public.build_reviews (
            review_id SERIAL PRIMARY KEY, 
            build_id INT REFERENCES public.builds(id) ON DELETE CASCADE, 
            user_id INT NOT NULL, 
            rating INT CHECK (rating >= 1 AND rating <= 5), 
            comment TEXT, 
            review_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
        );
    END IF;
END;
$$;


ALTER FUNCTION public.create_build_reviews_table() OWNER TO postgres;

--
-- TOC entry 289 (class 1255 OID 16424)
-- Name: create_builds_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_builds_table() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'builds') THEN
        CREATE TABLE public.builds (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            hero_id INT REFERENCES public.heroes(id) ON DELETE CASCADE,
            total_cost INT DEFAULT 0,
			build_owner VARCHAR(50),
			win_rate NUMERIC(5,2),
			games_played INT DEFAULT 0
        );
    END IF;
END;
$$;


ALTER FUNCTION public.create_builds_table() OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 16421)
-- Name: create_heroes_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_heroes_table() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'heroes') THEN
        CREATE TABLE public.heroes (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) UNIQUE NOT NULL,
            tier VARCHAR(3),
            win_rate NUMERIC(5,2),
            pick_rate NUMERIC(5,2),
            ban_rate NUMERIC(5,2)
        );
    END IF;
END;
$$;


ALTER FUNCTION public.create_heroes_table() OWNER TO postgres;

--
-- TOC entry 271 (class 1255 OID 16423)
-- Name: create_items_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_items_table() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'items') THEN
        CREATE TABLE public.items (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) UNIQUE NOT NULL,
            cost INT,
			type VARCHAR(50)
        );
    END IF;
END;
$$;


ALTER FUNCTION public.create_items_table() OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 16426)
-- Name: create_public_tables(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_public_tables() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM create_heroes_table();
    PERFORM create_abilities_table();
    PERFORM create_items_table();
    PERFORM create_builds_table();
    PERFORM create_build_items_table();
	PERFORM create_build_reviews_table();
END;
$$;


ALTER FUNCTION public.create_public_tables() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 16491)
-- Name: create_user_schema_and_role(character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    role_name VARCHAR := LOWER(_username);
    schema_name VARCHAR := CONCAT('schema_', LOWER(_username));
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE FORMAT('CREATE ROLE %I LOGIN PASSWORD %L;', role_name, _user_password);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = schema_name) THEN
        EXECUTE FORMAT('CREATE SCHEMA %I AUTHORIZATION %I;', schema_name, role_name);
    END IF;

	EXECUTE 'ALTER ROLE ' || quote_ident(role_name) || ' SET client_encoding TO ''UTF8'';';

    PERFORM copy_tables_with_data(schema_name);

    EXECUTE FORMAT('CREATE INDEX IF NOT EXISTS idx_heroes_name ON %I.heroes USING btree (name);', schema_name);
    EXECUTE FORMAT('CREATE INDEX IF NOT EXISTS idx_items_name ON %I.items (name);', schema_name);
    EXECUTE FORMAT('CREATE INDEX IF NOT EXISTS idx_builds_heroes ON %I.builds (hero_id);', schema_name);
    
    PERFORM create_build_cost_trigger(schema_name);

    EXECUTE FORMAT('REVOKE ALL ON SCHEMA public FROM %I;', role_name);
    EXECUTE FORMAT('REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM %I;', role_name);
    EXECUTE FORMAT('REVOKE CREATE ON SCHEMA public FROM %I;', role_name);
    
    EXECUTE FORMAT('GRANT USAGE ON SCHEMA public TO %I;', role_name);
	EXECUTE FORMAT('GRANT INSERT ON ALL TABLES IN SCHEMA public TO %I;', role_name);
	EXECUTE FORMAT('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO %I;', role_name);
	EXECUTE FORMAT('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO %I;', role_name);

	EXECUTE FORMAT('REVOKE CREATE ON SCHEMA public FROM %I;', role_name);

    EXECUTE FORMAT('GRANT USAGE, CREATE ON SCHEMA %I TO %I;', schema_name, role_name);
    EXECUTE FORMAT('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO %I;', schema_name, role_name);
	EXECUTE FORMAT('GRANT ALL ON ALL TABLES IN SCHEMA %I TO %I;', schema_name, role_name);
	EXECUTE FORMAT('GRANT ALL ON ALL SEQUENCES IN SCHEMA %I TO %I;', schema_name, role_name);
	EXECUTE FORMAT('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO %I;', schema_name, role_name);
	
    EXECUTE FORMAT('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO %I;', role_name);
    
END;
$$;


ALTER FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 16419)
-- Name: create_user_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_user_table() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'public' AND table_name = 'users') THEN
        CREATE TABLE public.users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(50) UNIQUE NOT NULL,
            user_password TEXT NOT NULL
        );
    END IF;
END;
$$;


ALTER FUNCTION public.create_user_table() OWNER TO postgres;

--
-- TOC entry 281 (class 1255 OID 25210)
-- Name: delete_ability(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.abilities WHERE id = $1;',
        schema_name
    ) USING _ability_id;
END;
$_$;


ALTER FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) OWNER TO postgres;

--
-- TOC entry 282 (class 1255 OID 25248)
-- Name: delete_all_tables_in_schema(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_all_tables_in_schema(schema_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    table_record RECORD;
BEGIN
    FOR table_record IN 
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = schema_name
    LOOP
        EXECUTE FORMAT('DROP TABLE IF EXISTS %I.%I CASCADE', schema_name, table_record.table_name);
    END LOOP;
END;
$$;


ALTER FUNCTION public.delete_all_tables_in_schema(schema_name character varying) OWNER TO postgres;

--
-- TOC entry 277 (class 1255 OID 25208)
-- Name: delete_build(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_build(schema_name character varying, _build_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.builds WHERE id = $1;',
        schema_name
    ) USING _build_id;
END;
$_$;


ALTER FUNCTION public.delete_build(schema_name character varying, _build_id integer) OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 25261)
-- Name: delete_build_items(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.build_items WHERE build_id = $1;',
        schema_name
    ) USING _build_id;
END;
$_$;


ALTER FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 25265)
-- Name: delete_by_comment(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.build_reviews WHERE comment ILIKE $1',
        schema_name
    ) USING '%' || search_text || '%';
END;
$_$;


ALTER FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) OWNER TO postgres;

--
-- TOC entry 284 (class 1255 OID 25267)
-- Name: delete_by_description(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.items WHERE description = $1;',
        schema_name
    ) USING search_text;
END;
$_$;


ALTER FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 25269)
-- Name: delete_by_first_column(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    first_column_name VARCHAR;
BEGIN
    EXECUTE FORMAT(
        'SELECT column_name FROM information_schema.columns 
         WHERE table_schema = %L AND table_name = %L
         ORDER BY ordinal_position LIMIT 1',
        schema_name, table_name
    ) INTO first_column_name;
    
    IF first_column_name IS NULL THEN
        RAISE EXCEPTION 'Первый столбец не найден для таблицы %I.%I', schema_name, table_name;
    END IF;

    EXECUTE FORMAT(
        'DELETE FROM %I.%I WHERE %I = $1',
        schema_name, table_name, first_column_name
    ) USING search_value;
END;
$_$;


ALTER FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 25207)
-- Name: delete_hero(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.heroes WHERE id = $1;',
        schema_name
    ) USING _hero_id;
END;
$_$;


ALTER FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) OWNER TO postgres;

--
-- TOC entry 286 (class 1255 OID 25209)
-- Name: delete_item(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_item(schema_name character varying, _item_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.items WHERE id = $1;',
        schema_name
    ) USING _item_id;
END;
$_$;


ALTER FUNCTION public.delete_item(schema_name character varying, _item_id integer) OWNER TO postgres;

--
-- TOC entry 273 (class 1255 OID 25251)
-- Name: delete_record_by_id(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.%I WHERE id = $1',
        schema_name, table_name
    ) USING record_id;
END;
$_$;


ALTER FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 25211)
-- Name: delete_review(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_review(schema_name character varying, _review_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'DELETE FROM %I.build_reviews WHERE review_id = $1;',
        schema_name
    ) USING _review_id;
END;
$_$;


ALTER FUNCTION public.delete_review(schema_name character varying, _review_id integer) OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 25262)
-- Name: delete_schema(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_schema(schema_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE FORMAT('DROP SCHEMA %I CASCADE;', schema_name);
END;
$$;


ALTER FUNCTION public.delete_schema(schema_name character varying) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 25258)
-- Name: delete_table(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_table(schema_name character varying, table_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE FORMAT(
        'DROP TABLE IF EXISTS %I.%I CASCADE',
        schema_name, table_name
    );
END;
$$;


ALTER FUNCTION public.delete_table(schema_name character varying, table_name character varying) OWNER TO postgres;

--
-- TOC entry 268 (class 1255 OID 41279)
-- Name: get_abilities_by_hero_name(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) RETURNS TABLE(ability_id integer, hero_id integer, ability_name character varying, description text, ability_type character varying)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT a.id AS ability_id, a.hero_id, a.name AS ability_name, a.description, a.type AS ability_type
         FROM %I.abilities a
         JOIN %I.heroes h ON a.hero_id = h.id
         WHERE h.name ILIKE $1',
        schema_name, schema_name
    ) USING '%' || hero_name || '%';
END;
$_$;


ALTER FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 41280)
-- Name: get_builds_by_hero(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) RETURNS TABLE(id integer, name character varying, hero_id integer, total_cost integer, build_owner character varying, win_rate numeric, games_played integer)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT b.id, b.name, b.hero_id,b.total_cost, b.build_owner, b.win_rate, b.games_played
         FROM %I.builds b
         JOIN %I.heroes h ON b.hero_id = h.id
         WHERE h.name ILIKE $1',
        schema_name, schema_name
    ) USING '%' || hero_name || '%';
END;
$_$;


ALTER FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 41281)
-- Name: get_items_by_build(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) RETURNS TABLE(id integer, name character varying, cost integer, type character varying)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT i.id, i.name, i.cost, i.type
         FROM %I.items i
         JOIN %I.build_items bi ON i.id = bi.item_id
         WHERE bi.build_id = $1',
        schema_name, schema_name
    ) USING build_id;
END;
$_$;


ALTER FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 41282)
-- Name: get_items_by_hero(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) RETURNS TABLE(id integer, name character varying, cost integer, type character varying)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT i.id, i.name, i.cost, i.type
         FROM %I.items i
         JOIN %I.heroes h ON i.id = h.hero_id
         WHERE h.name ILIKE $1',
        schema_name, schema_name
    ) USING '%' || hero_name || '%';
END;
$_$;


ALTER FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) OWNER TO postgres;

--
-- TOC entry 278 (class 1255 OID 25213)
-- Name: get_last_build_by_hero(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) RETURNS TABLE(build_id integer, hero_name character varying, name character varying, build_owner character varying, total_cost integer, win_rate numeric, games_played integer)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY 
    EXECUTE FORMAT(
        'SELECT b.id, h.name, b.name, b.build_owner, b.total_cost, b.win_rate, b.games_played
         FROM %I.builds b join %I.heroes h on b.hero_id = h.id
         WHERE h.name = $1
         ORDER BY b.id DESC
         LIMIT 1;',
        schema_name, schema_name
    ) USING _hero_name;
END;
$_$;


ALTER FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) OWNER TO postgres;

--
-- TOC entry 269 (class 1255 OID 41283)
-- Name: get_reviews_by_build(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) RETURNS TABLE(review_id integer, build_id integer, user_id integer, rating integer, comment text, review_date timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT r.review_id, r.build_id, r.user_id, r.rating, r.comment, r.review_date
         FROM %I.build_reviews r
         WHERE r.build_id = $1',
        schema_name
    ) USING input_build_id;
END;
$_$;


ALTER FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 32873)
-- Name: get_table_columns(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) RETURNS TABLE(column_name character varying, data_type character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cols.column_name::VARCHAR, 
        cols.data_type::VARCHAR
    FROM information_schema.columns AS cols
    WHERE cols.table_schema = schema_name
      AND cols.table_name = p_table_name; 
END;
$$;


ALTER FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) OWNER TO postgres;

--
-- TOC entry 280 (class 1255 OID 25249)
-- Name: get_table_data(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_table_data(schema_name character varying, table_name character varying) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY EXECUTE FORMAT(
        'SELECT * FROM %I.%I',
        schema_name, table_name
    );
END;
$$;


ALTER FUNCTION public.get_table_data(schema_name character varying, table_name character varying) OWNER TO postgres;

--
-- TOC entry 279 (class 1255 OID 40997)
-- Name: get_top_build_reviews(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_top_build_reviews(schema_name character varying) RETURNS TABLE(build_id integer, avg_rating numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT br.build_id, ROUND(AVG(br.rating), 2) AS avg_rating
         FROM %I.build_reviews br
         GROUP BY br.build_id
         ORDER BY avg_rating DESC
         LIMIT 10',
        schema_name
    );
END;
$$;


ALTER FUNCTION public.get_top_build_reviews(schema_name character varying) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 41135)
-- Name: get_top_builds(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_top_builds(schema_name character varying) RETURNS TABLE(id integer, name character varying, hero_id integer, total_cost integer, build_owner character varying, win_rate numeric, games_played integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT *
         FROM %I.builds
         ORDER BY win_rate DESC
         LIMIT 10',
        schema_name
    );
END;
$$;


ALTER FUNCTION public.get_top_builds(schema_name character varying) OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 41066)
-- Name: get_top_heroes(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_top_heroes(schema_name character varying) RETURNS TABLE(id integer, name character varying, tier character varying, win_rate numeric, pick_rate numeric, ban_rate numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT *
         FROM %I.heroes
         ORDER BY win_rate DESC
         LIMIT 10',
        schema_name
    );
END;
$$;


ALTER FUNCTION public.get_top_heroes(schema_name character varying) OWNER TO postgres;

--
-- TOC entry 291 (class 1255 OID 41351)
-- Name: get_top_items_for_hero(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) RETURNS TABLE(id integer, name character varying, cost integer, type character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    EXECUTE FORMAT(
        'SELECT i.id, i.name, i.cost, i.type
         FROM %I.items i
         JOIN %I.build_items bi ON i.id = bi.item_id
         JOIN %I.builds b ON bi.build_id = b.id
         JOIN %I.heroes h ON b.hero_id = h.id
         WHERE h.name ILIKE %L
         ORDER BY i.cost DESC',
        schema_name, schema_name, schema_name, schema_name, '%' || hero_name || '%'
    );
END;
$$;


ALTER FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 24724)
-- Name: insert_ability(character varying, integer, character varying, text, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'INSERT INTO %I.abilities (hero_id, name, description, type) VALUES ($1, $2, $3, $4);',
        schema_name
    ) USING _hero_id, _name, _description, _type;
END;
$_$;


ALTER FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 24726)
-- Name: insert_build(character varying, character varying, integer, character varying, numeric, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'INSERT INTO %I.builds (name, hero_id, build_owner, win_rate, games_played) VALUES ($1, $2, $3, $4, $5);',
        schema_name
    ) USING _name, _hero_id, _build_owner, _win_rate, _games_played;
END;
$_$;


ALTER FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) OWNER TO postgres;

--
-- TOC entry 275 (class 1255 OID 24727)
-- Name: insert_build_item(character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'INSERT INTO %I.build_items (build_id, item_id) VALUES ($1, $2);',
        schema_name
    ) USING _build_id, _item_id;
END;
$_$;


ALTER FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 33010)
-- Name: insert_build_review(text, integer, integer, integer, text, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE format(
        'INSERT INTO %I.build_reviews (build_id, user_id, rating, comment) VALUES ($1, $2, $3, $4)',
        schema_name
    )
    USING p_build_id, p_user_id, p_rating, p_comment;
END;
$_$;


ALTER FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 290 (class 1255 OID 24723)
-- Name: insert_hero(character varying, character varying, character varying, numeric, numeric, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'INSERT INTO %I.heroes (name, tier, win_rate, pick_rate, ban_rate) VALUES ($1, $2, $3, $4, $5);',
        schema_name
    )
    USING _name, _tier, _win_rate, _pick_rate, _ban_rate;
END;
$_$;


ALTER FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) OWNER TO postgres;

--
-- TOC entry 270 (class 1255 OID 24725)
-- Name: insert_item(character varying, character varying, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
    EXECUTE FORMAT(
        'INSERT INTO %I.items (name, cost, type) VALUES ($1, $2, $3);',
        schema_name
    ) USING _name, _cost, _type;
END;
$_$;


ALTER FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) OWNER TO postgres;

--
-- TOC entry 288 (class 1255 OID 16488)
-- Name: recalculate_build_cost(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.recalculate_build_cost() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
BEGIN
    
    EXECUTE FORMAT(
        'UPDATE %I.builds
         SET total_cost = (
             SELECT COALESCE(SUM(i.cost), 0)
             FROM %I.build_items bi
             JOIN %I.items i ON bi.item_id = i.id
             WHERE bi.build_id = $1
         )
         WHERE id = $1',
        TG_TABLE_SCHEMA, TG_TABLE_SCHEMA, TG_TABLE_SCHEMA 
    )
    USING NEW.build_id; 

    RETURN NEW;
END;
$_$;


ALTER FUNCTION public.recalculate_build_cost() OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 16492)
-- Name: register_user(character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.register_user(_username character varying, _user_password text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    add_result TEXT;
BEGIN
    PERFORM create_user_table();

    add_result := add_user_to_table(_username, _user_password);

    IF add_result = 'User added successfully' THEN
        PERFORM create_user_schema_and_role(_username,_user_password);
        RETURN 'User registered successfully with schema and role';
    ELSE
        RETURN add_result;
    END IF;
END;
$$;


ALTER FUNCTION public.register_user(_username character varying, _user_password text) OWNER TO postgres;

--
-- TOC entry 287 (class 1255 OID 33148)
-- Name: search_by_comment(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) RETURNS TABLE(review_id integer, build_id integer, user_id integer, rating integer, comment text, review_date timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE FORMAT(
        'SELECT * FROM %I.build_reviews WHERE comment ILIKE $1',
        schema_name
    ) USING '%' || search_text || '%';
END;
$_$;


ALTER FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 33079)
-- Name: search_by_description(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_by_description(schema_name character varying, search_text character varying) RETURNS TABLE(id integer, name character varying, description text)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE FORMAT(
        'SELECT a.id, a.name, a.description
         FROM %I.abilities a
         WHERE a.description ILIKE $1;',
        schema_name
    ) USING '%' || search_text || '%';
END;
$_$;


ALTER FUNCTION public.search_by_description(schema_name character varying, search_text character varying) OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 25268)
-- Name: search_by_first_column(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
DECLARE
    first_column_name VARCHAR;
BEGIN
    EXECUTE FORMAT(
        'SELECT column_name FROM information_schema.columns
         WHERE table_schema = %L AND table_name = %L
         ORDER BY ordinal_position LIMIT 1',
        schema_name, table_name
    ) INTO first_column_name;

    RETURN QUERY EXECUTE FORMAT(
        'SELECT * FROM %I.%I WHERE %I = %L',
        schema_name, table_name, first_column_name, search_value
    );
END;
$$;


ALTER FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) OWNER TO postgres;

--
-- TOC entry 283 (class 1255 OID 33147)
-- Name: search_by_name(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_by_name(schema_name character varying, search_text character varying) RETURNS TABLE(id integer, name character varying, tier character varying, win_rate numeric, pick_rate numeric, ban_rate numeric)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE FORMAT(
        'SELECT * FROM %I.heroes WHERE name ILIKE $1',
        schema_name
    ) USING '%' || search_text || '%';
END;
$_$;


ALTER FUNCTION public.search_by_name(schema_name character varying, search_text character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16451)
-- Name: items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.items (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    cost integer,
    type character varying(50)
);


ALTER TABLE public.items OWNER TO postgres;

--
-- TOC entry 272 (class 1255 OID 25270)
-- Name: search_item_by_name(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) RETURNS SETOF public.items
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY
    EXECUTE FORMAT(
        'SELECT * FROM %I.items WHERE name ILIKE $1',
        schema_name
    ) USING '%' || search_text || '%';
END;
$_$;


ALTER FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 42646)
-- Name: update_record_by_id(character varying, character varying, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_record_by_id(schema_name character varying, input_table_name character varying, record_id integer, input_column_name character varying, new_value character varying) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    column_data_type text;
BEGIN
    SELECT data_type INTO column_data_type
    FROM information_schema.columns
    WHERE table_schema = schema_name
      AND table_name = input_table_name
      AND column_name = input_column_name;

    IF column_data_type IS NULL THEN
        RAISE EXCEPTION 'Столбец % не найден в таблице %', input_column_name, input_table_name;
    END IF;

    EXECUTE FORMAT(
        'UPDATE %I.%I SET %I = $1::%s WHERE id = $2',
        schema_name, input_table_name, input_column_name, column_data_type
    ) USING new_value, record_id;
END;
$_$;


ALTER FUNCTION public.update_record_by_id(schema_name character varying, input_table_name character varying, record_id integer, input_column_name character varying, new_value character varying) OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16437)
-- Name: abilities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.abilities (
    id integer NOT NULL,
    hero_id integer,
    name character varying(100) NOT NULL,
    description text,
    type character varying(50)
);


ALTER TABLE public.abilities OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16436)
-- Name: abilities_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.abilities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.abilities_id_seq OWNER TO postgres;

--
-- TOC entry 4971 (class 0 OID 0)
-- Dependencies: 219
-- Name: abilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.abilities_id_seq OWNED BY public.abilities.id;


--
-- TOC entry 225 (class 1259 OID 16472)
-- Name: build_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.build_items (
    build_id integer NOT NULL,
    item_id integer NOT NULL
);


ALTER TABLE public.build_items OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 24707)
-- Name: build_reviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.build_reviews (
    review_id integer NOT NULL,
    build_id integer,
    user_id integer NOT NULL,
    rating integer,
    comment text,
    review_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT build_reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.build_reviews OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 24706)
-- Name: build_reviews_review_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.build_reviews_review_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.build_reviews_review_id_seq OWNER TO postgres;

--
-- TOC entry 4975 (class 0 OID 0)
-- Dependencies: 226
-- Name: build_reviews_review_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.build_reviews_review_id_seq OWNED BY public.build_reviews.review_id;


--
-- TOC entry 224 (class 1259 OID 16460)
-- Name: builds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.builds (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hero_id integer,
    total_cost integer DEFAULT 0,
    build_owner character varying(50),
    win_rate numeric(5,2),
    games_played integer DEFAULT 0
);


ALTER TABLE public.builds OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16459)
-- Name: builds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.builds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.builds_id_seq OWNER TO postgres;

--
-- TOC entry 4978 (class 0 OID 0)
-- Dependencies: 223
-- Name: builds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.builds_id_seq OWNED BY public.builds.id;


--
-- TOC entry 218 (class 1259 OID 16428)
-- Name: heroes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.heroes (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    tier character varying(3),
    win_rate numeric(5,2),
    pick_rate numeric(5,2),
    ban_rate numeric(5,2)
);


ALTER TABLE public.heroes OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 16427)
-- Name: heroes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.heroes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.heroes_id_seq OWNER TO postgres;

--
-- TOC entry 4981 (class 0 OID 0)
-- Dependencies: 217
-- Name: heroes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.heroes_id_seq OWNED BY public.heroes.id;


--
-- TOC entry 221 (class 1259 OID 16450)
-- Name: items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.items_id_seq OWNER TO postgres;

--
-- TOC entry 4983 (class 0 OID 0)
-- Dependencies: 221
-- Name: items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.items_id_seq OWNED BY public.items.id;


--
-- TOC entry 4721 (class 2604 OID 16440)
-- Name: abilities id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.abilities ALTER COLUMN id SET DEFAULT nextval('public.abilities_id_seq'::regclass);


--
-- TOC entry 4726 (class 2604 OID 24710)
-- Name: build_reviews review_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.build_reviews ALTER COLUMN review_id SET DEFAULT nextval('public.build_reviews_review_id_seq'::regclass);


--
-- TOC entry 4723 (class 2604 OID 16463)
-- Name: builds id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.builds ALTER COLUMN id SET DEFAULT nextval('public.builds_id_seq'::regclass);


--
-- TOC entry 4720 (class 2604 OID 16431)
-- Name: heroes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.heroes ALTER COLUMN id SET DEFAULT nextval('public.heroes_id_seq'::regclass);


--
-- TOC entry 4722 (class 2604 OID 16454)
-- Name: items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.items ALTER COLUMN id SET DEFAULT nextval('public.items_id_seq'::regclass);


--
-- TOC entry 4902 (class 0 OID 16437)
-- Dependencies: 220
-- Data for Name: abilities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.abilities (id, hero_id, name, description, type) FROM stdin;
327	60	Conjure Image	Conjures an illusion of Terrorblade that deals damage.	Healing
14	2	Culling Blade	Axe spots a weakness and strikes, dealing pure damage.	Debuffing
97	19	Degen Aura	Grants self an aura that applies movement speed slow to enemy units within the radius.	Vision-based
15	3	Prickly	Grants both outgoing damage amplification and debuff duration amplification to enemy units behind the Bristleback.	Crowd_Control
1	1	Greevil's Greed	Synthesizes additional gold from killed enemy units and from Bounty Runes.Alchemist earns base bonus gold and extra bonus gold per last hit. If Alchemist kills another unit which grants gold within a short duration, an additional instance of bonus gold is added to the total.	Buffing
2	1	Hero Model	Al and the Chemist's hero model has the following hidden  innate abilities.They both may only perform or utilize the ability's functions upon a successful channeling.	Stunning
3	1	Acid Spray	Enemy units who step across the contaminated terrain take damage per second and have their armor reduced.	Healing
4	1	Unstable Concoction	Brews up an unstable concoction that the Alchemist can throw at an enemy hero, to stun and deal damage within the radius around the explosion. The longer the brew, the more the damage and the longer the stun. While brewing, Alchemist moves faster.\nThe brew reaches its max power after a period of time, and explodes himself if not thrown before the max brew time.	Damage-dealing
5	1	Unstable Concoction Throw	The longer the concoction brews, the more the potent. Throw it before it blows up!	Vision-based
6	1	Corrosive Weaponry	Applies a stacking slow and base attack damage reduction on affected enemy units.	Debuffing
7	1	Berserk Potion	Throws a potion at an allied unit, applying a basic dispel and granting them bonus attack speed, movement speed and health regeneration.	Healing
8	1	Chemical Rage	The ogre enters chemically induced rage, reducing its base attack time while granting bonus movement speed and health regeneration.	Vision-based
9	2	Coat of Blood	Grants bonus armor retroactively per hero kill credited to Axe.	Vision-based
10	2	One Man Army	Grants Axe temporary  strength based on Axe's current armor.Allied heroes venturing too close to Axe passively disables this effect linearly.	Vision-based
11	2	Berserker's Call	Axe taunts nearby enemy units, forcing them to attack him, while he gains bonus armor for the duration.	Vision-based
12	2	Battle Hunger	Enrages an enemy unit, causing it to take damage over time until it kills another unit or the duration ends. The damage is increased by a factor of Axe's armor.The enemy is also slowed as long as it is facing away from Axe.	Stunning
13	2	Counter Helix	After a set number of incoming attacks, Axe performs a helix counter attack, dealing pure damage to all nearby enemies.	Vision-based
16	3	Viscous Nasal Goo	Covers a target in snot, causing it to have reduced armor and movement speed. Multiple casts stack and refresh the duration.	Stunning
17	3	Quill Spray	Sprays enemy units with quills dealing damage in an area of effect around Bristleback. Deals bonus damage for every time a unit was hit by Quill Spray in the last 14 seconds.	Debuffing
18	3	Bristleback	Bristleback takes less damage if hit on the sides or rear.	Crowd_Control
19	3	Hairball	Coughs a quill-packed hairball toward and erupts at the point-targeted location.	Stunning
20	3	Warpath	Works himself up into a fury every time Bristleback casts a spell. Grants self movement speed bonus.	Damage-dealing
21	4	Rawhide	Grants a stack of permanent health bonus as the game goes on.	Crowd_Control
22	4	Horsepower	Grants flat bonus movement speed per current  strength and increases the self max movement speed cap.	Healing
23	4	Hero Model	Centaur's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Buffing
24	4	Hoof Stomp	After a brief windup, Centaur slams the ground, stunning and damaging nearby enemy units. He can move during the delay, but is disarmed.	Debuffing
25	4	Double Edge	Strikes a mighty blow at melee range, damaging both himself and a small area around the target. Deals extra damage based on Centaur's  strength.Centaur cannot die from Double Edge.	Crowd_Control
26	4	Retaliate	Counters all attacks, dealing damage back to the attacker. Returns a fixed amount plus a percentage based on Centaur's  strength.	Stunning
27	4	Work Horse	Centaur hitches a cart behind him and can cast Hitch A Ride on an ally.	Debuffing
28	4	Hitch A Ride	Centaur tosses an ally into a cart hitched behind him. While in the cart, the ally can still cast and attack normally, but cannot move independently or be targeted by opponents. Non-targeted effects can still affect the hitched ally. Melee heroes has their attack range increased while being hitched.	Healing
29	4	Stampede	Centaur leads all allied units into a vicious charge, causing them to move through units at max speed while trampling enemy units.	Debuffing
30	5	Reins of Chaos	Chaos Knight has a chance to create an additional illusion per illusion-creating source.	Crowd_Control
31	5	Phantasmagoria	Grants additional incoming damage reduction to all of Chaos Knight's illusions within the radius.	Crowd_Control
32	5	Chaos Bolt	Throws a mysterious bolt of energy at the target unit that stuns for a random duration and deals random damage.	Healing
33	5	Reality Rift	Teleports Chaos Knight and all illusions he has and the targeted unit to a point along the line between both of them.Applies armor reduction to the affected enemy unit.	Buffing
34	5	Chaos Strike	Chaos Knight and his illusions' attacks have a chance to deal a critical strike of varying strength, in addition to a lifesteal for the percentage of the damage.	Vision-based
35	5	Phantasm	Summons several phantasm copies of the Chaos Knight from alternate dimensions.	Debuffing
36	6	Break of Dawn	Valora reveals the entire map gradually whenever the sun rises.The Fog of War returns after the reveal duration.	Vision-based
37	6	Starbreaker	Dawnbreaker whirls her hammer multiple times, damaging enemies with her attack plus bonus damage.	Crowd_Control
38	6	Celestial Hammer	Dawnbreaker hurls her weapon at a target, damaging enemies struck along the way. The hammer pauses for a duration at the destination before flying back to her.	Damage-dealing
39	6	Converge	Dawnbreaker can recall Brightmaul at any time, pulling her towards it so they meet in the middle.Both Dawnbreaker and Brightmaul create fire trails as they converge.	Buffing
40	6	Luminosity	After a number of attacks, Dawnbreaker powers up, charging her next attack with a critical strike that heals allied heroes within the radius.	Crowd_Control
41	6	Solar Guardian	Dawnbreaker creates a pulsing effect at a location near an allied hero anywhere on the map, damaging enemy units while healing allied units per pulse within the radius.	Vision-based
42	6	Solar Guardian Land	Dawnbreaker can now onto the targeted area anytime. While airborne, the landing point of Solar Guardian can now be moved to the desired location.\nGrants evasion bonus to allied units within the Solar Guardian radius while Dawnbreaker is airborne.	Crowd_Control
43	9	Stone Remnant	Call a Stone Remnant to the target location. Stone Remnants have no vision and are invulnerable, and interacts with all Earth Spirit's abilities.Gains additional charges whenever Earth Spirit levels up to certain levels.	Vision-based
44	9	Boulder Smash	Smashes the target enemy or allied unit, sending them in the direction he is facing. The traveling unit damages all enemy units it hits.	Debuffing
45	9	Rolling Boulder	Gathers himself into a boulder and rolls toward the target location after a slight delay, deals damage and stuns enemy units.Earth Spirit will stop if he collides with an enemy hero or when being disabled.	Damage-dealing
46	9	Geomagnetic Grip	Pulls the targeted allied or enemy unit. Enemy units struck by the pulled target will be silenced.	Buffing
47	9	Enchant Remnant	Earth Spirit temporarily enchants a hero, granting them the properties of a Stone Remnant. After a short duration the remnant shatters, releasing the hero and damaging nearby enemies.	Crowd_Control
48	9	Magnetize	Magnetizes enemy units in a small nearby area, causing them to take damage for a short duration.Magnetized heroes cause nearby Stone Remnants to explode, destroying the remnant and refreshing Magnetize's duration on all nearby enemies. This process can repeat multiple times.	Healing
49	10	Spirit Cairn	Creates a cairn upon Earthshaker's death that grants self experience, vision radius centered around it, and acts as a pathing blocker.	Crowd_Control
50	10	Slugger	Turns enemy heroes killed into projectiles that that travel in a straight line from its origin position, and deals damage to all enemy units it passes through.	Healing
51	10	Hero Model	Under certain conditions, Earthshaker has unobstructed movement through all created Fissures.	Stunning
52	10	Fissure	Slams the ground with a mighty totem, creating an impassable ridge of stone while stunning and damaging enemy units along its line.	Crowd_Control
53	10	Enchant Totem	Empowers Earthshaker's totem, causing it to deal extra damage and grants bonus attack range on the next attack.	Debuffing
54	10	Aftershock	Causes the earth to shake underfoot, adding additional damage and stuns to nearby enemy units when Earthshaker casts his abilities.	Buffing
55	10	Echo Slam	Creates shockwaves that travel through the ground, damaging enemy units. Affected enemy heroes releases two echos.	Vision-based
56	12	Blood Magic	Mana cost of all sources are converted to current health costs for the Sacred Warrior.Huskar does not have mana.	Buffing
57	12	Hero Model	Huskar's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Buffing
58	12	Inner Fire	In a fiery rage, Huskar pushes all nearby enemies away to a fixed distance, silences and damages them.	Damage-dealing
59	12	Burning Spear	Ignites his spears aflame with his health, dealing damage over time with his regular attack.Multiple attacks will stack additional damage.	Stunning
60	12	Berserker's Blood	Huskar's injuries feed his power, giving increased attack speed, magic resistance and health regeneration based on missing health.Grants health regeneration bonus based on a percentage of Huskar's  strength.	Buffing
61	12	Life Break	Leaps at an enemy target, shattering a percentage of its current health, and slowing both its movement speed and attack speed.	Debuffing
62	13	Admiral's Rum	Douses himself with the Admiral's signature rum upon taking additional player-based damage instances when reaching a certain health threshold.The Rum buff grants bonus movement speed and damage reduction for a period of time.	Crowd_Control
63	13	Torrent	Summons a rising torrent that, after a short delay, stuns and hurls enemy units into the sky.	Stunning
64	13	Tidebringer	Grants increased damage and cleaves a large area of effect in front of him for a single strike.	Buffing
65	13	X Marks the Spot	Targets a hero, marks its position with an X, and returns it to the X after several seconds.	Debuffing
66	13	Return	Kunkka can return the marked hero to the X at anytime during the duration.	Damage-dealing
67	13	Tidal Wave	Calls upon a tidal wave from behind Kunkka that deals damage, disarms, and drags enemy units along it.	Crowd_Control
68	13	Ghostship	Summons a ghostly ship that sails through the battle before smashing apart, damaging and stunning all enemies caught near the wreckage.	Crowd_Control
69	14	Outfight Them!	Grants self a health restoration amplification buff when attacking a higher level enemy hero.	Buffing
70	14	Overwhelming Odds	Turns the enemies' numbers against them, dealing damage per enemy unit and grant self bonus attack speed.	Crowd_Control
71	14	Press the Attack	Removes debuffs and disables from the target friendly unit, and grants bonus movement speed and bonus health regenertaion for a short time.	Vision-based
72	14	Moment of Courage	When attacked, Tresdin counter-attacks with bonus lifesteal immediately.	Buffing
73	14	Duel	Tresdin and the target enemy hero are forced to attack each other for a short duration. Neither hero can use items nor abilities.Grants permanent bonus attack damage to the victor during the Duel duration.	Damage-dealing
74	15	Feast	Deals damage and lifesteals for a percentage of the target's max health.	Vision-based
75	15	Rage	Launch into a maddened rage. Grants bonus magic resistance, bonus movement speed and debuff immunity for the entire duration.	Healing
76	15	Unfettered	Further descends into a violent fury. Grants bonus magic resistance and bonus status resistance for the entire duration.	Debuffing
77	15	Open Wounds	Rends an enemy unit, slowing the affected target's movement speed and allowing all allied units to regain health for a percentage of the damage dealt to the target.Lifesteals from all damage instances dealt, including spell damage.The affected enemy unit recovers its movement speed over the duration.	Stunning
78	15	Ghoul Frenzy	Grants self bonus movement speed and bonus attack speed.	Debuffing
79	15	Infest	Infests the body of a target unit, becoming undetectable, and healing for a portion of his max health every second while inside.Does not work on enemy heroes.	Debuffing
80	15	Consume	Eats the host body from the inside out, exploding from within and dealing damage to enemy units within the radius.If the infested unit is an enemy creep or a neutral creep, Lifestealer takes control of the unit's ability to move and attack.	Stunning
81	17	Heart of Darkness	The Darkness grants Night Stalker health regeneration amplification during nighttime, but applies a self health regeneration reduction during daytime.	Buffing
82	17	Night Reign	Starts the game at nighttime, with nighttime having a longer duration than daytime.	Buffing
83	17	Hero Model	Balanar's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Crowd_Control
84	17	Void	Creates a damaging void that slows an enemy unit and deals damage.	Debuffing
85	17	Crippling Fear	Horrifies all nearby enemy units, causing them to become silenced and take damage over time while near the Night Stalker.	Buffing
86	17	Hunter in the Night	Night Stalker is in his element at night, attacking and moving with great swiftness.	Damage-dealing
87	17	Dark Ascension	Smothers the sun and summons instant darkness, so that he might use his powers at their fullest.Grants Night Stalker flying movement, unobstructed vision and bonus attack damage during his ascension.	Crowd_Control
88	18	Dumb Luck	Ogre Magi's max  intelligence is always 0. Strength grants him mana and mana regeneration instead.	Healing
89	18	Learning Curve	The Ogre starts the game with no ability points, but they are compensated fairly later in the game by the Frog.	Buffing
90	18	Hero Model	The Ogre's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Buffing
91	18	Fireblast	Blasts an enemy unit with a wave of fire, dealing damage and stunning the target.	Buffing
92	18	Ignite	Drenches the target and another random unit in volatile chemicals, causing it to burst into flames. The target is in immense pain, taking damage and moving more slowly.	Crowd_Control
93	18	Bloodlust	Incites a frenzy in a friendly unit, increasing its movement speed and attack speed. Can be cast on buildings.	Crowd_Control
94	18	Unrefined Fireblast	Blasts an enemy unit with a wave of fire, dealing damage and bonus damage corresponding to the Ogre's  strength and stunning the target.	Debuffing
95	18	Fire Shield	Creates a fire shield around the targeted ally, absorbing a percentage of the damage of next few attacks from enemy heroes.	Stunning
96	18	Multicast	Enables Ogre Magi to cast his abilities and items multiple times per cast, disregarding its cooldown.Each of Ogre Magi's abilities has its own Multicast buffer range.	Stunning
98	19	Healing Hammer	The all seeing one converts all spell damage dealt into self heal per second.	Healing
99	19	Hero Model	Omniknight's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
100	19	Purification	Instantly heals a friendly unit and damages all nearby enemy units.	Stunning
101	19	Repel	Grants debuff immunity to the targeted allied hero, as well as bonus  strength and health regeneration corresponding to the amount of current active debuffs on them.	Damage-dealing
102	19	Hammer of Purity	Purifies his weapon, dealing pure damage based on a percentage of his main attack damage.	Healing
103	19	Guardian Angel	Grants allied units within the point-targeted location physical damage immunity.	Vision-based
104	20	Colossal	The Beast deals conditional bonus attack damage on buildings and illusions.	Crowd_Control
105	20	Hero Model	The Beast's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
106	20	Onslaught	The Beast charges! Enemy units are damaged and stunned on impact. The longer the charge, the farther the onslaught.	Crowd_Control
107	20	Begin Onslaught	The Beast begins the rush to the specified location.	Debuffing
108	20	Trample	The Beast stomps over everything, all enemy units around it are damaged per distance traveled.	Debuffing
109	20	Uproar	The Beast accumulate Uproar stacks for every offensive damage instance it takes.	Damage-dealing
110	20	Rock Throw	The Beast throws a rock at the target location that stuns and damages enemies.	Debuffing
111	20	Pulverize	The Beast grabs the target enemy and slams them into the ground repeatedly. Damages and stuns other enemy units within the radius.Each consecutive slam increases the damage dealt.	Buffing
112	21	Flesh Heap	Grants bonus  strength retroactively that increases each time Pudge kills an enemy Hero or when it dies in his vicinity.	Healing
113	21	Hero Model	Pudge's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Buffing
114	21	Meat Hook	Launches a bloody hook toward a unit or location. The hook will snag the first unit it encounters, dragging the unit back to Pudge and dealing damage.	Damage-dealing
115	21	Rot	A toxic cloud that deals intense damage and slows movement — harming not only enemy units but Pudge himself.	Healing
116	21	Meat Shield	Negates all damage types from all sources while active.	Stunning
117	21	Dismember	Chows down on an enemy unit. Pudge pulls the unit at a rate up to a certain minimum distance.	Damage-dealing
118	21	Eject	The allied hero inside Pudge is regenerating a percentage of their max health per second.Pudge may eject the swallowed allied hero at any time.	Stunning
119	22	Seaborn Sentinel	Grants Slardar bonus health regeneration, bonus armor, bonus attack damage, and bonus movement speed in certain water-based terrains.	Healing
120	22	Hero Model	Slardar's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Healing
121	22	Guardian Sprint	Slardar slithers ahead, moving significantly faster with phase movement.	Damage-dealing
122	22	Slithereen Crush	Slams the ground, stunning and damaging nearby enemy land units. After the stun, the affected units are slowed.	Debuffing
123	22	Bash of the Deep	After a number of attacks, Slardar bashes its attacking target.	Healing
124	22	Corrosive Haze	Reduces the affected enemy target's armor, provides True Sight and vision over it, revealing invisibility.	Vision-based
125	23	Herd Mentality	Applies a buff that grants an experience gain factor on the allied hero in Barathrum's team with the least experience.	Crowd_Control
126	23	Charge of Darkness	Fixes his sight on an enemy unit and starts charging through all objects.Barathrum starts charging at a lower charge speed, and gradually winds-up to the max charge speed.	Crowd_Control
127	23	Bulldoze	Grants bonus movement speed and status resistance to ram through enemies.	Healing
128	23	Greater Bash	Has a chance to stun and knockback an enemy unit on an attack that deals a portion of Barathrum's current movement speed as damage.	Debuffing
129	23	Planar Pocket	Increases self magic resistance and redirecting enemy hero spells in a radius towards him.	Crowd_Control
130	23	Nether Strike	Spirit Breaker slips into the nether realm, reappearing next to his hapless victim and striking it.	Crowd_Control
131	24	Vanquisher	Sven's attacks conditionally deal more attack damage to stunned enemy units.	Stunning
132	24	Wrath of God	Grants Sven additional base attack damage per  strength with a trade-off.	Damage-dealing
133	24	Storm Hammer	Sven unleashes his magical gauntlet that deals damage and stuns enemy units in a small area around the target.	Vision-based
134	24	Great Cleave	Sven cleaves all nearby enemy units with his attack.	Buffing
135	24	Warcry	Sven's Warcry heartens his allied heroes for battle, increasing their armor and movement speed.	Buffing
136	24	God's Strength	Channels his rogue strength, granting bonus damage and slow resistance for the duration.	Buffing
137	26	Exposure Therapy	Timbersaw restores a flat amount of mana per tree destroyed.	Debuffing
138	26	Whirling Death	Damages and destroys trees within the radius centered around Timbersaw.Deals bonus damage per destroyed tree, while reducing the affected enemy hero's primary attribute for a brief duration.	Buffing
139	26	Timber Chain	Fires a chain that embeds itself in the first tree it hits, pulling Timbersaw towards it.Deals damage to enemy units within Timbersaw's travel path.	Healing
140	26	Reactive Armor	Grants bonus armor and bonus health regeneration whenever an enemy hero attacks Timbersaw.	Crowd_Control
141	26	Twisted Chakram	Launches a secondary saw-blade that deals damage and applies movement speed slow on affected enemy units correspondingly to their current health it passes through, then returns to Timbersaw.	Vision-based
142	26	Flamethrower	Releases a destructive flame in the direction Timbersaw is facing.Deals damage per second, applies a movement speed slow and destroys trees.	Damage-dealing
143	26	Chakram	Launches a saw-blade that deals damage, applies a movement speed slow, and cuts down trees in its path when launched and retracted.	Debuffing
144	26	Return Chakram	Returns the Chakram to Timbersaw.	Damage-dealing
145	27	Craggy Exterior	Applies an attack damage reduction debuff stack per attack taken to enemy units attacking Tiny.	Damage-dealing
146	27	Insurmountable	Grants bonus status resistance and bonus slow resistance per current  strength.	Stunning
147	27	Avalanche	Bombards an area with rocks, continuously doing small intervals of damage and stun to enemy units.	Stunning
148	27	Toss	Grabs the nearest ally or enemy unit within the radius around Tiny and launches it at the target unit or rune to deal damage where they land.	Buffing
149	27	Tree Grab	Grabs a tree to whack enemies on the head for a limited number of attacks. Attacks deal more damage and fully splash on units along the way. The tree can be thrown, to deal your attack to a unit at a distance.Grants Tiny bonus attack range.	Crowd_Control
150	27	Tree Throw	Tiny throws the wielded tree at the target unit, proccing his attack on it and splashing damage around the target.	Debuffing
151	27	Tree Volley	Tiny channels to throw random trees within the radius towards the targeted area that deals Tiny's attack damage to enemies in that area with each tree thrown.Each tree tossed causes Tiny to instant attack affected units, applying various attack effects.	Buffing
152	27	Grow	Tiny gains craggy mass, increasing his attack damage, and armor while slowing his attack speed.	Stunning
153	28	Nature's Guise	Grants Treant a tree-walking buff whenever he hasn't taken damage for a period of time. Nearby trees and Nature's Grasp grants Treant bonus movement speed.	Debuffing
154	28	Primeval Power	The Protector's primeval instincts grants itself bonus base attack damage per hero level.	Damage-dealing
155	28	Hero Model	The presence of the protector himself globally causes all trees to respawn faster under certain conditions.	Healing
156	28	Nature's Grasp	Creates vines towards the target location. Vines slow down and deal damage to enemies that walk through.	Healing
157	28	Leech Seed	Plants a life-sapping seed in an enemy unit, draining its health, while simultaneously slowing it.	Damage-dealing
158	28	Living Armor	Infuses the target hero or structure with a protective coating which heals the target and provides bonus armor.	Buffing
159	28	Eyes In The Forest	Treant enchants a tree, which grants him unobstructed vision in that location.	Crowd_Control
160	28	Overgrowth	Summons an overgrowth of vines and branches around Treant that prevent afflicted enemies from moving, blinking, going invisible, or attacking.	Healing
161	29	Bitter Chill	Applies an attack speed slow on all enemy units within the radius.	Buffing
162	29	Ice Shards	Throws a ball of frozen energy that damages all enemies it comes in contact with. When the ball reaches its target destination the shards are released, creating a temporary path blocker.	Debuffing
163	29	Snowball	Tusk begins rolling into a snowball. Allies within a certain radius can also be added to the snowball by right-clicking on them, even while the snowball is moving.	Vision-based
164	29	Launch Snowball	Launch the snowball toward the target.	Vision-based
165	29	Tag Team	Creates a negative debuff aura around Tusk, causing enemy units that are attacked under it to have reduced movement speed.	Stunning
166	29	Drinking Buddies	Reaches out to tag an allied unit and pulls them closer. Grants both Tusk and the tagged ally bonus movement speed and attack damage once tagged.	Stunning
167	29	Walrus Kick	Kicks the closest enemy unit in a targeted direction, stunning, damaging, and slowing them.Upon the affected unit landing, Tusk deals damage to all heroes within the landing radius.	Damage-dealing
168	29	Walrus PUNCH!	Applies a critical strike so powerful it launches its victim into the air. The victim is slowed upon landing.	Damage-dealing
169	36	Big Game Hunter	Grants bonus gold to Gondar for kills or assists on an enemy hero with a kill streak.	Vision-based
170	36	Cutpurse	Steals gold per offensive unit-targeted ability cast, including item abilities, on enemy heroes.	Vision-based
171	36	Shuriken Toss	Hurls a deadly shuriken at an enemy unit, dealing damage and slowing the target.	Stunning
172	36	Jinada	Deals bonus damage and stealing some unreliable gold when off-cooldown.	Debuffing
173	36	Shadow Walk	Gondar becomes invisible and gains the ability to move through other units until he attacks or uses an ability.If he breaks the invisibility with an attack, that attack will stun the target for a short duration.	Crowd_Control
174	36	Friendly Shadow	Applies an invisibility buff based on Shadow Walk of the corresponding level. Has a slightly longer fade time duration for allied heroes.	Vision-based
175	36	Track	Grants True Sight, applies an incoming damage amplification debuff, and information on how much gold the affected enemy unit is carrying.If the Tracked enemy unit dies, Gondar collects a bonus gold bounty.Track does not break Gondar's Shadow Walk upon cast.	Buffing
176	38	Precision Aura	Grants nearby ranged allied heroes bonus  agility based on Drow's, with the precision increasing as Drow levels up.	Buffing
177	38	Vantage Point	The Drow conditionally deals bonus attack damage when attacking from high ground.	Healing
178	38	Frost Arrows	Adds a freezing effect to Drow's attacks, slowing enemy movement and dealing bonus damage.	Debuffing
179	38	Gust	Releases a wave that silences, and knocks enemy units back relatively to how close they are to Drow.	Debuffing
180	38	Multishot	Releases a flurry of arrows in continuous salvos within an area in front of her.	Damage-dealing
181	38	Glacier	Forms a hill of ice mass beneath her. While standing on the hill, the glacier grants allied heroes bonus attack range and high ground advantage — attacks cannot miss and has flying vision.The front of the hill obscures vision and cannot be moved through except Drow.	Stunning
182	38	Marksmanship	Drow's attacks has a chance to ignore the enemy's base armor.Enemy heroes venturing too close to Drow passively disables this effect.	Crowd_Control
183	39	Immolation	The Ember Spirit immolates and deals damage per second within the radius centered around itself.	Stunning
184	39	Searing Chains	Unleashes fiery bolas that wrap around nearby enemies, anchoring them in place and dealing damage each second.	Damage-dealing
185	39	Sleight of Fist	Dashes around with blazing speed, attacking all enemy units within the area-targeted radius, then returning to his start location.	Buffing
186	39	Flame Guard	Surrounds himself with a ring of fire that consumes incoming magic damage, absorbing a percentage of the damage taken.If the barrier depletes, the damage per second component is also lost.	Crowd_Control
187	39	Activate Fire Remnant	The inquisitive aspect of fire casts himself to the Fire Remnant to arrive at.Dashes out to all active Fire Remnants, destroying them and dealing damage in an area and then moving to the nearest Remnant.	Healing
188	39	Fire Remnant	Sends a Fire Remnant that dashes to the target location.	Stunning
189	40	Distortion Field	Applies an attack projectile speed factor on offensive and incoming enemy attack projectiles within the radius, centered around the time master.Affects projectiles even if Faceless Void isn't the attacked target.	Damage-dealing
190	40	Hero Model	Other Bash sources are passively disabled on Faceless Void.	Damage-dealing
191	40	Backtrack	The time manipulator has a chance to avoid damage entirely.	Crowd_Control
192	40	Time Walk	Rushes to a target location while healing up from any damage taken in the last few seconds.	Healing
193	40	Reverse Time Walk	Available for a short time after landing Time Walk. If used in a certain time period, Faceless Void will reverses time walk back to the previous cast location.	Buffing
194	40	Time Dilation	Traps all nearby enemies in a time dilation field, decelerating their cooldowns and slowing their movement and attack speed per cooldown extended.Deals damage per second per ability currently on cooldown.	Stunning
195	40	Time Lock	Adds a chance for an attack to lock an enemy unit in time while attacking it a second time.	Healing
196	40	Chronosphere	Trap all units caught within the radius and causes Faceless Void to move very quickly inside it. Reveals invisible enemies within the sphere.	Vision-based
197	40	Time Zone	Alters the speed of various properties for both allied and enemy units within the squared-zone.	Vision-based
198	42	Mistwoods Wayfarer	Has a chance to redirect attacks to a tree, destroying it in the process.The tree search radius is centered around Hoodwink.	Debuffing
199	42	Hero Model	Hoodwink's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Healing
200	42	Armor Corruption	Granted by learning a  talent. Hoodwink's attacks now reduce the affected target's armor by a certain amount.	Vision-based
201	42	Acorn Shot	Fires an acorn attack on the target enemy. The acorn bounces to nearby targets, slowing them and dealing a percentage of Hoodwink's attack with bonus damage.	Damage-dealing
202	42	Bushwhack	Tosses a net trap that stuns enemy heroes if they are near a tree in the area. Affected enemies take damage over time.	Stunning
203	42	Scurry	When activated, Hoodwink gains bonus movement speed, attack and cast range, phased movement, and tree-walking for a brief time.	Buffing
204	42	Decoy	Turns invisible instantaneously while increasing her movement speed.	Crowd_Control
205	42	Hunter's Boomerang	Tosses a boomerang in an arc that deals damage as it pass through enemy units.	Healing
206	42	Sharpshooter	Charges up and fires a deadly bolt from her crossbow.After winding up for a while, the bolt is fired automatically and Hoodwink is knocked back for a distance from the force of the shot.	Buffing
207	42	End Sharpshooter	Release the charged shot, regain ability to move and attack.	Crowd_Control
208	44	Switch Discipline	Switches between his weapons — the Kazurai Katana and the Shodo Sai.Reduces cooldown by a flat amount per hero level.	Buffing
209	44	Hero Model	Kez's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Buffing
210	44	Echo Slash	Slashes forward in a line with his Katana, instant attacks and applies a brief slow to affected enemy units.	Vision-based
211	44	Falcon Rush	Grants the ability to rush towards enemy units within a distance, delivering echoing secondary attacks.Applies an attack rate reduction and an attack range reduction. Kez's attack rate is less affected by attack speed sources while active.	Buffing
212	44	Grappling Claw	Swings on a grappling hook toward the unit-targeted tree or enemy. Applies movement speed slow on the affected enemy until Kez reaches it.	Debuffing
213	44	Talon Toss	Throws a Sai at the unit-targeted enemy, dealing damage and silences all enemy units within the radius upon impact.	Buffing
214	44	Kazurai Katana	All abilities and Katana-based attacks apply health regeneration reduction, with a stacking damage over time debuff corresponding to a portion of the attack damage dealt.	Buffing
215	44	Shodo Sai	All abilities and Sai-based attacks have a chance to apply a mark that slows affected enemy units.	Buffing
216	44	Shodo Sai Cancel	Instantly cancels parrying incoming attacks.	Stunning
217	44	Raptor Dance	Enters into an uncontrollable channeling and grants debuff immunity with absolute magic resistance.	Healing
218	44	Raven's Veil	Releases a veil of smoke within the radius while briefly reducing their vision. Affected enemy units regain their vision over time.	Damage-dealing
219	45	Lunar Blessing	Increases the attack damage for Luna and nearby allied heroes. At nighttime, the Lunar Blessing is Global.	Buffing
220	45	Hero Model	Luna's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Vision-based
221	45	Lucent Beam	Calls a beam of lunar energy down upon an enemy, damaging and briefly stunning them.	Debuffing
222	45	Lunar Orbit	The Moon Rider's glaive spirals out, rotates around her, and instantly attacks enemy units for a portion of her attack damage.	Healing
223	45	Moon Glaives	Luna's attacks bounce between enemy units, and deals lesser damage per bounce.	Vision-based
224	45	Eclipse	Temporary obscures the sun, turning the day into night, while showering enemies with lucent strikes in a radius around Luna.There is a max number of times that a single target can be struck.	Vision-based
225	46	Mana Shield	Creates a shield that absorbs incoming damage in exchange for Medusa's mana.	Healing
226	46	Venomous Volley	After a number of attacks on the same enemy unit, the Gorgon's attack applies a movement speed slow, attack speed slow, and a cast point slow.	Debuffing
227	46	Hero Model	The Gorgon's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Healing
228	46	Split Shot	Magically splits her shot into several arrows. These arrows deal a lower percent of her normal damage.	Vision-based
229	46	Mystic Snake	Fires an energy bolt that jumps from target to target dealing damage. After it reaches its last target, it returns and to replenishes her mana.	Buffing
230	46	Cold Blooded	When Medusa is unit-targeted by an enemy spell, a single-target Mystic Snake is sent back towards the enemy.	Crowd_Control
231	46	Gorgon's Grasp	Fires a volley of damaging arrows in a straight line, with each grouping covering a larger radius than the previous.	Crowd_Control
232	46	Stone Gaze	Any enemy units looking at Medusa will have both their movement speed and attack speed slowed.	Damage-dealing
233	47	Sticky Fingers	Grants Meepo an additional choice when activating neutral item tokens.	Stunning
234	47	Pack Rat	The Prime can wield any item in the neutral item slot with certain exceptions.When the Prime or a Clone uses an item in the neutral slot, all other Meepos have this item go on a reduced cooldown.	Vision-based
235	47	Hero Model	Meepo's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Stunning
236	47	Earthbind	Tosses a net at the target point, rooting down all enemy units within the radius.	Vision-based
237	47	Poof	A Meepo can teleport to another Meepo or itself after its cast point, dealing damage in both the departure and arrival locations.	Debuffing
238	47	Ransack	Steals health from the enemy with each strike and heals all other Meepos for that amount.	Buffing
239	47	Dig	Dispels Meepo, becomes invulnerable and hidden shortly, while restoring its health.	Stunning
240	47	MegaMeepo	The Prime mounts all other lesser Meepos within the radius around him on top of his shoulders.While in this form, the other lesser Meepos share their attributes with the Prime.	Stunning
241	47	MegaMeepo Fling	MegaMeepo flings the topmost Meepo towards a target, dealing damage and slowing their movement speed.	Stunning
242	47	Divided We Stand	Summons an imperfect, semi-autonomous duplicate of himself, which can gain gold and experience as he does and shares his experience, attributes and abilities.The Clones additionally has bonus magic resistance.	Buffing
243	47	Clone Model	The Meepo Clones are treated as heroes in most cases with certain exceptions.	Buffing
244	47	Clone Inventory	Clones neither can pick up, nor drop items. They cannot utilize item abilities within their inventory.	Stunning
245	48	Mischief	Changes Monkey King's shape to deceive opponents, using the environment nearby as inspiration for the disguise. Taking damage, attacking, or using any item or ability breaks the disguise.Negates damage for a brief moment upon transforming.	Vision-based
246	48	Revert Form	Reverts the Monkey King's current mischief shape to his original form.	Debuffing
247	48	Hero Model	Only Monkey King can disguise himself as a tree by design.	Crowd_Control
248	48	Boundless Strike	Enlarges his staff and slams it against the ground with True Strike, stunning enemy units in a line and damaging them with a critical hit based on his attack.	Buffing
249	48	Tree Dance	Jumps to a tree and perches atop it. If the tree Monkey King's is perched on is destroyed, he falls and is stunned.	Vision-based
250	48	Primal Spring	Springs out from his tree perch, damaging and slowing enemy units in proprotion to the channel duration toward the landing area.	Healing
251	48	Spring Early	Monkey King can spring off earlier on the current tree, this immediately ends Primal Spring.	Vision-based
252	48	Jingu Mastery	Monkey King's attacks awaken the Jingu Bang's power. Grants certain bonuses after a number of attacks on the same enemy hero within a duration.	Damage-dealing
253	48	Wukong's Command	Creates a circular formation of soldiers that spread out from his position. Grants Monkey King bonus armor for its duration.	Healing
254	48	Clone Inventory	These unselectable and uncontrollable Clones cannot use the items' active abilities. However, the items' passive effects are applied conditionally.	Stunning
255	49	Accumulation	Morphling receives half of the attribute gain per level, per half level, instead of full attribute gain per upon leveling up.	Stunning
256	49	Ebb	Sets the water elemental's primary attribute to  agility.	Damage-dealing
257	49	Flow	Sets the water elemental's primary attribute to  strength.All of Morphling's abilities now have their cooldowns accelerated correspondingly to its  strength to  agility ratio.	Vision-based
258	49	Hero Model	The water elemental's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Healing
259	49	Waveform	Surges forward, damaging enemy units in Morphling's path. Morphling is invulnerable during Waveform.	Damage-dealing
260	49	Adaptive Strike (Agility)	Launches a surge of water toward an enemy unit, dealing base damage plus additional damage based on Morphling's  agility.If Morphling's  agility is higher than  strength, the max agility damage factor is used.Also puts Adaptive Strike (Strength) on a fixed downtime.	Stunning
261	49	Adaptive Strike (Strength)	Launches a surge of water toward an enemy unit, stunning and knocking back the target based on Morphling's  strength.If Morphling's  strength is higher than  agility, the max stun duration is used.Also puts Adaptive Strike (Agility) on a fixed downtime.	Damage-dealing
262	49	Attribute Shift	Morphling pulls  strength points and pours them into  agility, and vice versa. The process is reversible.	Damage-dealing
263	49	Morph	Changes Morphling's form to match the targeted enemy, gaining their basic abilities. Morph can be toggled between the Morph Replicate sub-ability for its duration.	Crowd_Control
264	49	Morph Replicate	Toggles Morphling's form between his own and the replicated enemy.	Healing
265	50	Eelskin	Grants bonus evasion per allied Naga Siren-based illusion within the radius.	Crowd_Control
266	50	Hero Model	Naga's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Buffing
267	50	Mirror Image	Creates multiple images of herself under Slithice's control.	Crowd_Control
268	50	Ensnare	Interrupts the target and traps them in place, preventing movement or blinking.Can target invulnerable and sleeping units.	Damage-dealing
269	50	Reel In	The Siren channels and reels in all ensnared units to her within the radius without disabling them.	Stunning
270	50	Rip Tide	After a number of attacks of the Siren and her images, they all collectively and simutaneously hit all nearby enemy units with a damaging wave of water that lowers armor for a duration.	Crowd_Control
271	50	Deluge	The Siren and her images deals damage, applies a status resistance reduction, and set the affected enemy units' max movement speed to a certain value within the radius.	Vision-based
272	50	Song of the Siren	All enemy units in range of the Naga Siren are put into a magical stasis where they cannot act or be attacked, while allied units recover a percentage of their health per second.	Crowd_Control
273	50	Song of the Siren End	Releases all enemy units from Silthice's stasis so they can be targeted again.	Healing
274	51	Immaterial	The immaterial assassin is focuses inward, increasing her ability to evade enemy attacks.Additionally grants bonus evasion correspondingly to Mortred's current hero level.	Buffing
275	51	Hero Model	Mortred's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
276	51	Stifling Dagger	Throws a dagger slowing the enemy unit's movement speed, dealing a portion of Mortred's attack damage as instant attack and applying attack modifiers.	Crowd_Control
277	51	Phantom Strike	Teleports to a unit, friendly or enemy, and grants bonus attack speed while attacking if it's an enemy unit.	Debuffing
278	51	Blur	When activated, Mortred is untargetable, invisible, and enemy units only see the assassin's sihoulette within their vision radius.Casting Mortred's own abilities do not break the invisibility.	Crowd_Control
279	51	Fan of Knives	Releases a fan of sharp blades around her. Breaks while dealing a percentage of the victim's max health on impact.	Stunning
280	51	Coup de Grace	Mortred's attacks have a chance to proc the Deadly Focus buff, causing her next attack to be an ensured critical strike.	Buffing
281	52	Illusory Armaments	Items that grants bonus attack damage to Azwraith now grants base attack damage instead.	Stunning
282	52	Hero Model	Azwraith's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
283	52	Spirit Lance	Sends a magical spirit lance to a target enemy unit that damages and slows its movement speed.	Debuffing
284	52	Doppelganger	Briefly vanishes from the battlefield.After a delay, Phantom Lancer and any of his nearby illusions reappear at a random position within the targeted location, along with two additional doppelgangers with different properties, while extending all current illusions' duration.	Stunning
285	52	Phantom Rush	When activated, the Lancer quickly charges into range, gaining a temporary  agility boost when targeting an enemy unit for an attack.	Vision-based
286	52	Juxtapose	Has a chance to create an illusion of himself per attack.	Stunning
287	53	Unstable Current	Grants movement speed bonus per hero level.	Vision-based
288	53	Dynamo	Grants bonus spell amplification per current attack damage.	Buffing
289	53	Hero Model	Razor's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Vision-based
290	53	Plasma Field	Releases a wave of energetic plasma that grows in power as it expands, but also zaps on contraction, slowing and dealing damage to enemy units caught in its path.Each enemy unit can be hit twice, once each upon expanding and contracting. The further the distance, the potent the field.	Debuffing
291	53	Static Link	Creates a charged link between Razor and an enemy unit, the enemy unit loses attack damage incrementally while being linked to Razor.	Healing
292	53	Storm Surge	When attacked by an enemy, Razor has a chance to release a Forked Lightning that strikes the attacking source, prioritizing the attacker's unit-type.	Crowd_Control
293	53	Eye of the Storm	A powerful lightning storm strikes out at enemy units with the lowest health, dealing damage and reducing their armor.	Debuffing
294	54	Backstab	Every time Riki strikes his enemy from behind, he deals an  agility-based bonus damage.	Stunning
295	54	Hero Model	Riki's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Healing
296	54	Smoke Screen	Throws down a smoke bomb, silencing enemies, and causing them to miss attacks.	Vision-based
297	54	Blink Strike	Teleports behind the target unit, momentarily slowing them and striking for bonus damage if it is an enemy.	Healing
298	54	Tricks of the Trade	Phases out of the world while striking random enemy units from behind in an area around him.	Buffing
299	54	Cloak and Dagger	Riki fades into the shadows, becoming invisible. When Riki attacks, he becomes visible again.	Damage-dealing
300	55	Necromastery	Grants bonus attack damage per stack from unit kills, and loses a portion of stacks upon death.	Debuffing
301	55	Hero Model	Nevermore's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Crowd_Control
302	55	Shadowraze	Adds a stacking damage amplifier on the target that causes the enemy to take bonus Shadowraze damage per stack.	Buffing
303	55	Feast of Souls	Grants self bonus attack speed for an amount of time.	Healing
304	55	Presence of the Dark Lord	The presence itself reduces the armor of nearby enemies. Every enemy hero killed nearby further eats into the enemies' armor and applying additional reduction.	Debuffing
305	55	Requiem of Souls	Gathers his captured souls to release them as lines of demonic energy, units near Shadow Fiend can be damaged by several lines of energy.Enemy units damaged are feared, and have both its movement speed and magic resistance reduced with a duration based on each line hit.	Damage-dealing
306	56	Barracuda	When not visible to the enemy team, Slark gains bonus movement speed and bonus health regeneration.	Stunning
307	56	Dark Pact	After a short delay, Slark sacrifices some of his life blood, purging most negative debuffs and dealing damage to enemy units around him and to himself.	Crowd_Control
308	56	Pounce	Leaps forward and grabs the first enemy hero he connects with and applies Essence Shift stacks.That unit is now leashed, and can only move a limited distance away from Slark's landing position.	Vision-based
309	56	Essence Shift	Slark steals the life essence of enemy heroes with his attacks, draining each of their  attributes and converting them to bonus  agility.	Damage-dealing
310	56	Depth Shroud	Creates a dark cloud at the area-targeted location.All allies within the radius are affected by Shadow Dance's corresponding level.	Buffing
311	56	Shadow Dance	When activated, Slark hides himself in a cloud of shadows, becoming immune to both vision and True Sight.Attacking, casting abilities, and using items will not reveal Slark within the duration.	Buffing
312	57	Keen Scope	Grants self bonus attack range correspondingly to the caster's attack range type.	Damage-dealing
313	57	Shrapnel	Consumes a charge to launch a ball of shrapnel that showers and revealing the target area in explosive pellets.	Damage-dealing
314	57	Headshot	Increases Sniper's accuracy, giving him a chance to deal extra damage and briefly knocks back his enemies.	Buffing
315	57	Take Aim	Sniper takes aim with addtional attack range, he is slowed for the duration.	Vision-based
316	57	Concussive Grenade	Launches a grenade at the targeted location that damages enemy units, and applies knockback to both Sniper and all affected enemy units within the radius.Disarms, and applies a movement speed slow to affected enemy units after the knockback.	Crowd_Control
317	57	Assassinate	Locks onto a unit-targeted enemy.After a short aiming duration, Sniper fires a devastating shot at long range and mini-stuns the target.	Debuffing
318	58	Spectral	Spectre and her illusions have permanent phase movement, and ignores collision size. Other units may pass through it.	Vision-based
319	58	Spectral Dagger	Flings a dagger to draw a Shadow Path, dealing damage and slowing the movement speed of any enemies along the trail.	Buffing
320	58	Desolate	Spectre's attacks deal bonus damage to lone enemy units that does not have any allied units within a certain radius around them.	Damage-dealing
321	58	Dispersion	Damage done to Spectre is reflected as the same damage-type on her enemies, leaving her unharmed. The effect lessens with distance.	Damage-dealing
322	58	Haunt	Creates a number of haunted illusions to attack each enemy hero. At any moment during the duration, she exchanges place with the haunted image in reality.	Buffing
323	58	Shadow Step	Creates a single-target haunt illusion at a single visible enemy hero. At any moment during the duration, she can exchange place with the haunted image in reality.	Stunning
324	58	Reality	Spectre dissolves herself and exchanges places with a chosen haunt illusion.	Crowd_Control
325	60	Dark Unity	Grants Terrorblade's images within the aura radius outgoing damage bonus.	Healing
326	60	Reflection	Terrorblade brings forth an invulnerable dark reflection of all enemy heroes in a target area. Affected enemy heroes are slowed and attacked by their reflection.	Stunning
328	60	Metamorphosis	Terrorblade transforms into a powerful demon with a ranged attack.All Demon Form sources removes Demon Zeal, and vice versa.	Vision-based
329	60	Demon Zeal	Grants bonus health regeneration, bonus movement speed, and bonus attack speed within the radius to all affected illusions.However, the zeal does not work while metamorphed, and vice versa, the all Demon Form sources removes the zeal.	Stunning
330	60	Terror Wave	Causes a wave to travel outwards in all directions fearing all enemy units upon impact.	Stunning
331	60	Sunder	Severing the life from both Terrorblade and a target hero, exchanging a percentage of both units' current health.Some health points must remain after the exchange.	Crowd_Control
332	62	Maul	Grants bonus attack damage correspondingly to Ulfsaar's current health.	Buffing
333	62	Bear Down	Offensive debuffs applied by the Ursine Warrior last longer.	Damage-dealing
334	62	Earthshock	Ursa leaps forward and slams the earth, causing a powerful shock damaging and slowing all enemy units within the radius.	Buffing
335	62	Overpower	Using his skill in combat, Ursa gains increased attack speed and slow resistance for a number of subsequent attacks.	Stunning
336	62	Fury Swipes	Consecutive attacks to the same enemy deals more damage. If the same target is not attacked after a period of time, the bonus damage is lost.	Vision-based
337	62	Enrage	Goes into a frenzy, removing all exisiting debuffs while providing damage reduction and status resistance.	Stunning
338	63	Predator	Attacks apply an additional physical damage instance correspondingly to the target's current health and Viper's level.	Buffing
339	63	Hero Model	Viper's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
340	63	Become Universal	Some heroes have great base attributes, some has amazing attribute gains, but Viper — The Netherdrake has the talent to become  Universal.	Damage-dealing
341	63	Poison Attack	Intensifies Viper's venom, adding an effect to his normal attack that applies a stacking movement speed slow and magic resistance reduction while dealing damage over time.	Healing
342	63	Nethertoxin	Releases a Nethertoxin at the area-targeted location, affected enemy units take an increasing damage over time based on the duration they remain in it.	Healing
343	63	Corrosive Skin	Viper exudes an infectious toxin that damages and slows the attack speed of any enemy that damages the Netherdrake within the radius.	Stunning
344	63	Nosedive	The Netherdrake slams into the ground, disarming all affected enemy units within the radius.	Buffing
345	63	Viper Strike	Breaks the targeted enemy unit's passive abilities, slows its movement speed and attack speed, while dealing damage over time.The slowing effect reduces incrementally over the duration of the ability.	Healing
346	65	Death Rime	All of Kaldr's abilities now rimes and apply frost stacks. Deal damage per second and applies a movement slow per debuff stack.	Vision-based
347	65	Cold Feet	Places a frozen hex on an enemy unit that can be dispelled by moving away from the initial cast point.If the enemy unit doesn't move out of the given distance, it will be stunned and frozen in place after a duration.	Healing
348	65	Ice Vortex	Applies a movement speed slow and magic resistance reduction to enemy units within its radius.	Damage-dealing
349	65	Chilling Touch	Enhances Kaldr's attack with increased attack range, heavy magic damage, and movement speed slow.	Crowd_Control
350	65	Ice Blast	Launches a tracer toward any location, which must be triggered again to mark the final target point, this area will be blasted by a damaging explosion of hail.The further the tracer travels, the larger the explosion radius.	Vision-based
351	65	Release	Releases the ice blast to explode at the tracer's current location.	Healing
352	66	Blueheart Floe	Grants the Maiden incoming mana regeneration amplification.	Debuffing
353	66	Crystal Nova	A burst of damaging frost slows enemy movement speed and attack speed in the targeted area.	Damage-dealing
354	66	Frostbite	Encases an enemy unit in ice, prohibiting movement and attack, while dealing damage over time.	Crowd_Control
355	66	Arcane Aura	Grants additional mana regeneration to allied units on the map.Grants a greater bonus to allied units closer to the Maiden.	Healing
356	66	Crystal Clone	Creates a Crystal Clone of Rylai in her place while sliding to the area-targeted direction and disjointing incoming projectiles.	Buffing
357	66	Freezing Field	Surrounds Crystal Maiden with random icy explosions that slow enemies and deal massive damage.	Crowd_Control
358	66	Stop Freezing Field	Rylai commands the Freezing Field to halt as she wishes. She can now move, albeit slower, cast other abilities and attack during Freezing Field. Can still be interrupted by enemies.	Buffing
359	67	Witchcraft	Grants self bonus movement speed and cooldown reduction per hero level.	Damage-dealing
360	67	Mourning Ritual	Grants damage reduction over incoming damage instance taken for a period of time.	Crowd_Control
361	67	Crypt Swarm	Sends a swarm of winged beasts to savage enemy units in front of Death Prophet.	Healing
362	67	Silence	Fires a projectile that silences enemy units within a radius, preventing them from casting spells.	Debuffing
363	67	Spirit Siphon	Creates a spirit link between Death Prophet and an enemy unit, draining health from the enemy.	Healing
364	67	Exorcism	Unleashes spirits to drain the life of nearby enemy units and buildings. Grants bonus movement speed while active.At the end of the exorcism, all spirits return and heals Death Prophet for a portion of the damage dealt at the end of the duration.	Crowd_Control
365	68	Electromagnetic Repulsion	Repulses and knocks all enemy units back within the radius, whenever the Stormcrafter accumulates a certain amount of damage taken.	Vision-based
366	68	Thunder Strike	Repeatedly strikes the unit with lightning.Exposes the affected enemy target, with each strike damaging nearby enemy units in a small radius, slowing both their movement speed and attack speed for its duration.	Stunning
367	68	Glimpse	Teleports the target hero back to where it was a few seconds ago.	Vision-based
368	68	Kinetic Field	After a short formation time, creates a circular barrier of kinetic energy that manipulates affected enemy's movement speed to point where they cannot pass.	Debuffing
369	68	Kinetic Fence	After a short formation time, creates a wall-barrier of kinetic energy that slows enemy units down to point where they cannot pass.	Stunning
370	68	Static Storm	Creates a damaging static storm that also silences all enemy units in the area for the duration.The damage starts off weak, but gradually increases in power over the duration.	Vision-based
371	69	Rabble-Rouser	All neutral creeps conditionally deals more damage to enemy heroes.	Healing
372	69	Hero Model	Enchantress' talent granted auras are not affected by Break sources.	Debuffing
373	69	Impetus	Enchants her own attack while activated, causing it to deal additional distance-based damage between Enchantress and the enemy target. The farther the target, the greater the damage.	Debuffing
374	69	Enchant	Charms an enemy hero and slowing its movement speed in the process.	Buffing
375	69	Nature's Attendants	A cloud of wisps heals Enchantress and allied units nearby.	Debuffing
376	69	Sproink	Leaps backward and disjoints incoming projectiles.	Vision-based
377	69	Little Friends	Roots an enemy unit. Enchantress orders creeps of all factions, including neutral creeps, within the radius to attack the affected enemy unit.	Crowd_Control
378	69	Untouchable	Enchantress beguiles her enemies, slowing their attacks when she is attacked.	Damage-dealing
379	71	Double Trouble	Jakiro's attack launches two projectiles at the target with a 0.2s interval, but each deals 50% less damage. One of these attacks ignores melee heroes' default damage block.	Damage-dealing
380	71	Hero Model	Jakiro's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Buffing
381	71	Dual Breath	An icy blast followed by a wave of fire launches out in a path in front of Jakiro.	Damage-dealing
382	71	Ice Path	Creates a path of ice that stuns and damages enemy units that touch it.	Damage-dealing
383	71	Liquid Fire	Burns affected enemy units with fire added to his attack, while slowing their attack speed within the radius.	Stunning
384	71	Liquid Frost	Frosts affected enemy units with ice added to his attack, damaging them based on their max health per second, while slowing their movement speed within the radius.	Healing
385	71	Macropyre	Exhales a wide line of lasting flames, which deals damage per second to any enemy units caught in the fire.	Healing
386	73	Defilement	Grants flat bonus area-of-effect per current  intelligence.	Vision-based
387	73	Chronoptic Nourishment	The nihilist mana restores correspondingly to the attack damage dealt on the enemy unit.	Buffing
388	73	Split Earth	Splits the earth under enemies. Deals damage and stuns for a short duration.	Damage-dealing
389	73	Diabolic Edict	Saturates the area around Leshrac with magical explosions that deal pure damage to enemy units. The fewer units available to attack, the more damage those units will take.	Vision-based
390	73	Lightning Storm	Summons a lightning storm that blasts the target enemy unit, then jumps to nearby enemy units. Struck units have their movement speed slowed.	Damage-dealing
391	73	Nihilism	Leshrac and all enemy units within the radius turns ethereal. They cannot attack, have their movement speed slowed, and reduces all affected enemy units' magic resistance.	Damage-dealing
392	73	Pulse Nova	Creates pulse of damaging energy that affects enemy units around Leshrac once per second. Drains Leshrac's mana per pulse.	Damage-dealing
393	75	Combustion	Lina's damage instances above a certain threshold cause affected enemy units to combust and overheat.Deals damage per proc to to the enemy's allied units within the radius centered around the enemy unit.	Vision-based
394	75	Slow Burn	All Lina's spells now have a lower impact damage.However, it applies a portion of the impact damage as damage per second debuff as a trade-off.	Healing
395	75	Hero Model	Lina is considered a ground unit, despite its hero model showing otherwise.	Healing
396	75	Dragon Slave	Sends out a wave of fire that scorches every enemy in its path.	Vision-based
397	75	Light Strike Array	Summons a column of flames that damages and stuns enemies.	Debuffing
398	75	Fiery Soul	Grants a stack of bonus attack speed and bonus movement speed per enemy unit affected per ability cast.	Healing
399	75	Flame Cloak	Lina ascends and grants herself unobstructed movement, spell damage amplification and bonus magic resistance.	Stunning
400	75	Laguna Blade	Fires off a bolt of lightning at a single enemy unit, dealing massive damage.	Vision-based
401	76	To Hell and Back	Grants self bonus spell amplification and debuff duration amplification upon respawn.	Stunning
402	76	Earth Spike	Rock spikes burst from the earth along a straight path.Enemy units are hurled into the air, then are stunned and take damage when they fall.	Vision-based
403	76	Hex	Transforms an enemy unit into a harmless beast, with all special abilities disabled.	Debuffing
404	76	Mana Drain	Channels magical energy, drawing mana for himself and slowing the affected enemy unit over time.	Debuffing
405	76	Finger of Death	Rips at an enemy unit, trying to turn it inside-out with its massive infernal energy.	Crowd_Control
406	78	Sadist	The Sadist rewards himself with a bonus health regeneration and bonus mana regeneration stack for a duration per enemy hero kill.	Debuffing
407	78	Hero Model	Necrophos' hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Crowd_Control
408	78	Death Pulse	Releases a wave of death around Necrophos, dealing damage to enemy units and healing allied units.	Stunning
409	78	Ghost Shroud	Slips into the ethereal realm that separates the living from the dead, and emits a movement speed slow aura that affects enemy units around him.	Crowd_Control
410	78	Heartstopper Aura	Necrophos stills the hearts of his opponents, causing nearby enemy units to lose a percentage of their max health over time.	Vision-based
411	78	Death Seeker	Turns Necrophos into a large death projectile toward the unit-targeted location.	Crowd_Control
412	78	Reaper's Scythe	Stuns the target enemy hero, then deals damage based on per point of missing health of the targeted enemy unit. Any kills under this effect is credited to Necrophos.	Healing
413	79	Prognosticate	Accurately predicts where the next  Power Rune will spawn.	Healing
414	79	Clairvoyant Curse	Grants Nerif the Oracle bonus spell damage amplification per hero level.	Crowd_Control
415	79	Clairvoyant Cure	Grants Nerif the Oracle bonus heal amplification per hero level.	Stunning
416	79	Hero Model	Oracle's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
417	79	Fortune's End	Gathers his power into a bolt of scouring energy. When released, it damages, roots, and dispel enemy units of buff within the radius.The potency of the root duration corresponds to the channel time.	Healing
418	79	Fate's Edict	Enraptures an enemy unit and disarms them.	Crowd_Control
419	79	Purifying Flames	Deals damage to the affected unit before causing them to heal over time.	Crowd_Control
420	79	Rain of Destiny	Bring forth rain that damage and applies an incoming heal reduction for all affected enemy units within an area-targeted location.	Vision-based
421	79	False Promise	Applies a strong dispel on the affected allied hero upon cast.Delays certain health restoration sources and all incoming damage sources until the ability duration ends. Any healing that is delayed is doubled at the end of the duration.	Buffing
422	80	Ominous Discernment	Obstreperous Dissimilator grants the Harbinger flat bonus mana per  intelligence.	Buffing
423	80	Hero Model	The Harbinger's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Debuffing
424	80	Arcane Orb	Adds pure damage to attacks based on the current mana pool.	Buffing
425	80	Astral Imprisonment	Places a target unit into an astral prison. The hidden unit is invulnerable and disabled.When the astral prison implodes, it deals damage to the target and steals a percentage of their max mana.	Vision-based
426	80	Essence Flux	The Harbinger has a chance to restore a percentage of its max mana per ability cast.	Buffing
427	80	Sanity's Eclipse	Unleashes a psychic blast that deals damage to enemies based on the difference between the Harbinger's mana and the affected enemy's mana.	Crowd_Control
428	81	Puckish	Restores a portion of both its max health and max mana per incoming attack projectile disjointed.The restoration is more effective when disjointing incoming spell-based projectiles.	Debuffing
429	81	Hero Model	Puck's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Vision-based
430	81	Illusory Orb	Sends out an illusory orb that floats in a straight path, damaging enemy units along the way.At any point, Puck may teleport to the current location of the orb using Ethereal Jaunt.	Stunning
431	81	Ethereal Jaunt	Teleports to a flying Illusory Orb.	Vision-based
432	81	Waning Rift	Teleports to the area-targeted location and releases a burst of faerie dust that deals damage and silences enemy units within the radius.	Vision-based
433	81	Phase Shift	Puck briefly shifts and hides into another dimension where it is immune from harm.	Crowd_Control
434	81	Dream Coil	Creates a coil of volatile magic that latches, damages and leashes onto enemy heroes.	Buffing
435	83	Bondage	Reflects incoming spell damage of the same damage type on Akasha to the damage source.	Crowd_Control
436	83	Succubus	Grants a Spell Lifesteal aura that is stronger the closer enemies are from Akasha.	Healing
437	83	Masochist	Grants Akasha spell amplification bonus with a cost of some of her life blood.	Damage-dealing
438	83	Hero Model	Akasha's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
439	83	Shadow Strike	Hurls a poisoned dagger which deals large initial damage, and then deals damage over time. The poisoned unit has its movement speed slowed for  seconds.	Stunning
440	83	Blink	Short distance teleportation that allows Queen of Pain to move in and out of combat.	Buffing
441	83	Scream of Pain	The Queen of Pain lets loose a piercing scream around her, damaging nearby enemies.	Damage-dealing
442	83	Sonic Wave	Creates a gigantic wave of sound in front of Queen of Pain, dealing heavy damage to all enemy units in its wake and pushing them back.	Damage-dealing
443	85	Might and Magus	Craftily converts bonus outgoing spell amplification on himself to both bonus attack damage and bonus magic resistance.	Stunning
444	85	Hero Model	Rubick's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Debuffing
445	85	Telekinesis	Utilizes his telekinetic powers to lift the enemy unit into the air briefly, then hurls them back at the ground.The affected unit lands on the ground with such force that it stuns other enemy units within the radius.	Stunning
446	85	Telekinesis Land	Chooses the location the target will land when Telekinesis finishes.	Stunning
447	85	Fade Bolt	A powerful stream of arcane energy that travels between enemy units, dealing damage and reducing their attack damage.Each bolt bounce instance deal lesser damage.	Crowd_Control
448	85	Arcane Supremacy	Rubick's mastery of the arcane allows him to have a larger cast range and increased potency.	Healing
449	85	Spell Steal	Rubick studies the trace magical essence of the affected enemy hero, learning the secrets of the last ability that it casts.	Healing
450	85	Stolen Spell 1	The acquired ability of Spell Steal will take this slot.	Damage-dealing
451	85	Stolen Spell 2	The acquired sub-abilities of Spell Steal will take this slot, unless explicitly stated.	Healing
452	85	Transformation Sources Priorities	Multiple transformation sources' bonus and reductions fully stack with each other, with their attack range definitions and notes apply.	Buffing
453	86	Menace	Imbues attacks with an offensive stacking debuff that amplifies incoming damage taken by the affected enemy unit.	Damage-dealing
454	86	Shadow Servant	Creates illusions of dying heroes within the radius centered around Shadow Demon.	Debuffing
455	86	Hero Model	Shadow Demon's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Healing
456	86	Disruption	Sends the hero to the hidden dimension for a short duration.	Stunning
457	86	Disseminate	Whenever the affected unit takes damage, all enemy units, including the target itself if it is an enemy, also receive a portion of that damage.	Healing
458	86	Shadow Poison	Deals damage in a straight line and applies additional stack damage if the debuff is present.	Stunning
459	86	Shadow Poison Release	Releases the accumulated Shadow Poison from its stacks, dealing damage to all affected enemy units.	Buffing
460	86	Demonic Cleanse	Dispels debuffs continuously on the affected allied unit, then heals it at the end of the duration.	Healing
461	86	Demonic Purge	Dispels buff and slows the enemy unit for the duration. The unit slowly regains its movement speed until the end of the duration, upon which the damage is applied.	Damage-dealing
462	88	Brain Drain	If an enemy hero dies within the radius, Silencer permanently steals that enemy hero's  intelligence for himself.	Buffing
463	88	Irrepressible	Silencer cannot be silenced, be it offensively, from ally, or self-applied sources.	Vision-based
464	88	Hero Model	Silencer's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Vision-based
465	88	Arcane Curse	Applies a curse on affected enemy units within the radius, dealing damage over time and slowing their movement speed.	Crowd_Control
466	88	Glaives of Wisdom	Each attack drains the affected enemy hero's intelligence, grants Silencer wisdom, and deals additional damage corresponding to Silencer's current intelligence.	Damage-dealing
467	88	Last Word	Deals damage per second and applies a movement speed slow debuff to all enemy units within the radius per silence debuff on them.	Vision-based
468	88	Global Silence	Stops all sounds, preventing enemy heroes and units on the map from casting abilities.	Healing
469	89	Ruin and Restoration	Dragonus ruins and restores. He innately has bonus spell lifesteal.	Crowd_Control
470	89	Shield of the Scion	Grants Dragonus a bonus magical damage barrier buff, and scales correspondingly to Dragonus' hero level, per spell damage instance applied per enemy hero.	Debuffing
471	89	Staff of the Scion	Reduces all Dragonus' current abilities' cooldown per spell damage instance applied on enemy heroes.	Damage-dealing
472	89	Hero Model	Dragonus' hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Vision-based
473	89	Arcane Bolt	Launches a slow-moving bolt to an enemy unit that deals bonus damage based on current  intelligence.	Debuffing
474	89	Concussive Shot	Sets a long range shot that hits the closest hero. Upon impact, the projectile deals damage and slows all affected enemy units within the radius.	Buffing
475	89	Ancient Seal	Seals the targeted enemy unit with an ancient rune, reducing its magic resistance. If the unit is an enemy hero, the seal further silences it.	Buffing
476	89	Mystic Flare	Deals massive damage that is distributed evenly among all enemy heroes within the radius.	Healing
477	90	Galvanized	Storm Spirit gains a charge of 0.2 Mana Regen any time he kills an enemy hero or whenever an enemy hero dies within 1200 range. Gains 5 charges on leveling up Ball Lightning. Loses 3 charges on death. Every time Storm Spirit gains a charge he also permanently gains +0.1 Mana Regen.	Damage-dealing
478	90	Static Remnant	Creates an explosively charged image of Raijin that gives vision for a period of time. The image detonates and deals damage if an enemy unit comes near it.	Healing
479	90	Electric Vortex	Pulls an enemy unit to Raijin's location.	Damage-dealing
480	90	Overload	Overloads itself and creates an electrical charge upon an ability cast, which is released in the next attack. Deals damage and slows within the attacked enemy unit's radius.	Debuffing
481	90	Ball Lightning	Becomes a ball of volatile electricity, charging across the battlefield until he depletes his mana or reaches his target.	Healing
482	91	Eureka!	Grants Tinker an item-based cooldown reduction per  intelligence, with a cap.	Debuffing
483	91	Laser	Blinds and damages the unit-targeted enemy.	Stunning
484	91	March of the Machines	Enlists an army of robotic minions to destroy enemy units in an area around Tinker.	Stunning
485	91	Defense Matrix	Applies an all damage barrier and grants bonus status resistance to the affected ally unit.	Crowd_Control
486	91	Warp Flare	Fires a damaging flare towards an enemy unit and applies a debuff that reduces both the affected enemy unit's cast range and attack range.	Crowd_Control
487	91	Keen Conveyance	Globally convey to an ally unit conditionally. Self-cast automatically convey to the fountain after a certain distance.	Damage-dealing
488	91	Rearm	Resets the cooldown of Tinker's abilities. Does not affect item abilities cooldowns.	Debuffing
489	93	Gris-Gris	Starts the game with a neutral consumable — Gris-Gris.Can be consumed anytime to grant the stored gold to the Doctor.	Buffing
490	93	Paralyzing Cask	Launches a cask of paralyzing powder that ricochets between enemy units, stunning and damaging those it hits.	Vision-based
491	93	Voodoo Restoration	Focuses his voodoo to heal nearby allied units, keep the aura active costs mana per second.	Buffing
492	93	Maledict	Lays a curse on all enemy heroes within the radius, dealing damage per second for the entire duration.	Stunning
493	93	Voodoo Switcheroo	The Doctor turns into the Death Ward of its corresponding level while being hidden.	Crowd_Control
494	93	Cleft Death	Summons a deadly ward to attack enemy heroes within its attack range.	Healing
495	93	Death Ward	Can be controlled to attack a specific enemy unit or to stop attacking altogether.	Stunning
496	95	Withering Mist	Damage instances applied by Abaddon applies a dormant debuff that activates when the affected enemy unit is below the max health threshold.	Stunning
497	95	The Quickening	The Lord of Avernus' current cooldowns are reduced by a fixed amount per enemy hero death within the radius.	Vision-based
498	95	Mist Coil	Releases a coil of deathly mist that damages an enemy unit or heal an allied unit. at the cost of some of Abaddon's health.	Crowd_Control
499	95	Aphotic Shield	Summons dark energies around an allied unit that applies a strong dispel and creates a barrier to absorbs a set amount of damage before expiring.	Debuffing
500	95	Curse of Avernus	Applies a debuff that damages over time and slows the movement speed slow of the affected enemy unit.	Damage-dealing
501	95	Borrowed Time	Removes most debuffs when activated, all damage taken will self-heal instead for the entire duration.	Crowd_Control
502	96	Ichor of Nyctasha	Nyctasha has an obsession with making sure Bane's attributes are always evenly distributed.	Stunning
503	96	Hero Model	Bane is considered a ground unit, despite its hero model showing otherwise.	Vision-based
504	96	Enfeeble	Deals damage per second while reducing the affected enemy unit's total attack damage and cast range.	Damage-dealing
505	96	Brain Sap	Feasts on the vital energies of an enemy unit, self-heals and deals pure damage.	Damage-dealing
506	96	Nightmare	Puts the affected unit to sleep. Units affected are awaken when damaged.If the affected unit was directly attacked, the Nightmare is passed to the attacking unit.	Stunning
507	96	Nightmare End	Releases the victim from its ongoing Nightmare.	Healing
508	96	Fiend's Grip	Grips and disables an enemy unit. Deals damage and steals mana correspondingly of the affected unit's max mana per interval.	Damage-dealing
509	97	Smoldering Resin	Attacks apply a resin that deals a portion of Batrider's attack damage as damage per second.	Debuffing
510	97	Stoked	Grants the Rider a movement speed bonus and spell damage amplification bonus upon applying forced movement sources on self, or being offensively applied.	Stunning
511	97	Hero Model	Batrider is considered a ground unit, despite its hero model showing otherwise.	Debuffing
512	97	Sticky Napalm	Drenches an area in sticky oil, damaging and slowing the turn rate of enemy units within the radius.	Buffing
513	97	Flamebreak	Hurls an explosive cocktail that explodes when it reaches the target location and deals damage over time to enemy units in the area.	Vision-based
514	97	Firefly	Takes to the skies, laying down a trail of flames from the air. The trail damages any enemy units upon contact and destroys trees below Batrider.	Buffing
515	97	Flaming Lasso	Lassoes an enemy unit, disables and drags them in Batrider's wake.Teleport sources break the lasso.	Damage-dealing
516	101	Summon Convert	Summons a convert to fight alongside Chen corresponding to the selected Facet.	Debuffing
517	101	Penitence	Applies a movement speed slow debuff on the affected enemy unit.	Damage-dealing
518	101	Holy Persuasion	Persuades an enemy or neutral creep, excluding ancient creeps, for Chen's purposes.Grants Chen a portion of the gold bounty, with the experience of the persuaded unit alike a regular last hit.	Stunning
519	101	Divine Favor	Grants a soothing health regeneration aura within the radius.	Debuffing
520	101	Hand of God	Heals all ally heroes and his player-controlled units globally.	Healing
521	101	Martyrdom	Sacrifices the persuaded unit for a greater cause — To heal an ally unit, or to damage an enemy unit.	Buffing
522	103	Mental Fortitude	The Dark Seer's  intelligence value cannot be lower than the average of his current total  strength and  agility.	Debuffing
523	103	Quick Wit	Grants self flat bonus attack speed per current  intelligence.	Debuffing
524	103	Heart of Battle	Grants the Dark Seer a fraction of the sum of all heroes' movement speed within the radius, with a minuscule trade-off.	Stunning
525	103	Hero Model	Dark Seer's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Buffing
526	103	Vacuum	Creates a vacuum within the area-targeted location that sucks in all enemy units within the radius, interrupting and dealing damage.	Crowd_Control
527	103	Ion Shell	Surrounds the target unit with a bristling shield that damages enemy units in an area around it.	Stunning
528	103	Surge	Charges an ally unit with power, granting a brief max movement speed burst and phase movement. The ally unit cannot be slowed.	Damage-dealing
529	103	Normal Punch	The next attack on an enemy hero has True Strike, damages, and stuns correspondingly to the Dark Seer's moved distance.	Debuffing
530	103	Wall of Replica	Raises a wall of light that slows and creates replicas of any enemy hero who crosses it.These replicas serve at the Dark Seer's will, they last until destroyed or until the wall duration ends.	Healing
531	105	Weave	The Shadow Priest waives armor from affected enemy units respectively.	Vision-based
532	105	Nothl Boon	Converts heal values from overflown magic into a barrier that absorbs physical damage instances.	Crowd_Control
533	105	Poison Touch	Releases a cone poison that strike multiple enemy units.	Debuffing
534	105	Shallow Grave	Blesses an allied hero with Shallow Grave. The allied hero cannot die while under its protection, no matter how close to death.Grants bonus heal amplification corresponding to its health percentage.	Debuffing
535	105	Shadow Wave	Sends a bolt of power that arcs between allied units, healing them while damaging other enemy units within its radius.	Stunning
536	105	Bad Juju	Sacrifices a portion of current health to reduce the remaining cooldown of all abilities. Casting the Juju consecutively temporarily increases its health cost.	Healing
537	108	Sight Seer	Reduces the capture time and grants vision bonus to all captured Watchers.	Crowd_Control
538	108	Hero Model	Io's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Vision-based
539	108	Tether	The Fundamental tethers itself to an allied unit, granting bonus movement speed to both of them. Whenever Io restores health or mana, the tethered unit gains a portion of the regeneration.Tether breaks when either the allied unit moves too far away, or Io cancels it.	Vision-based
540	108	Break Tether	The Fundamental no longer tethers itself to the affected allied hero.	Buffing
541	108	Spirits	Summon a number of particles that dance in a circle around Io. If a particle collides with an enemy hero, it explodes and damages all enemy units within the radius.When its duration ends, all remaining particles explode.	Stunning
542	108	Spirits In	Calls and attracts in all the particle-like spirits to the Fundamental.	Damage-dealing
543	108	Spirits Out	Sends and repulses out all the particle-like spirits from the Fundamental.	Healing
544	108	Overcharge	Grants max health as bonus health regeneration.	Debuffing
545	108	Relocate	Teleports Io to any location globally. Upon the duration expires, Io will return to the original ability cast location.	Buffing
546	111	Solid Core	The Solid Core causes knockback distance of knockback sources to be less effective on Magnus, while additionally granting him slow resistance bonus.	Crowd_Control
547	111	Shockwave	Sends out a wave of force, damaging enemy units in a line, while knocking them toward Magnus and slowing them for a brief moment.	Damage-dealing
548	111	Empower	Grants the affected attack damage bonus for the duration.Additionally grants cleave damage if the affected ally unit is a melee unit.	Buffing
549	111	Skewer	Rushes forward and gores enemy units on his massive tusk. Enemy heroes affected on the way are damaged and will be dragged.Applies a movement speed slow to affected enemy heroes at the destination.	Vision-based
550	111	Horn Toss	Tosses any enemy units in front of Magnus, launching them upward and to his rear.Applies a stun and deals damage to all affected enemy units upon landing.	Debuffing
551	111	Reverse Polarity	Damages all affected enemy units and stuns them with a powerful slam.	Vision-based
552	112	Special Delivery	Marci's team starts the game with a slightly robust Flying Couriers.	Vision-based
553	112	Hero Model	Marci's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Debuffing
554	112	Dispose	Grabs an allied or enemy target and throws it effortlessly behind her, damaging and slowing the unit if it's an enemy.Damages and applies a movement speed slot to all enemy units within the landing radius.	Healing
555	112	Rebound	Marci bounds to the targeted unit, choosing a direction and distance she will spring away from it. Grants the targeted ally a short duration movement speed bonus.Upon reaching the unit, Marci leaps to her final destination, damaging and stunning enemies in the area.	Debuffing
556	112	Sidekick	Imbues a chosen allied hero and herself with bonus attack damage and lifesteal.Her lifesteal heals her ally, and the allied unit's lifesteal also heals Marci.	Debuffing
557	112	Bodyguard	Grants the affected allied hero bonus armor and protects them from a short distance.	Vision-based
558	112	Unleash	Marci taps a hidden power, increasing movement speed while gaining flurry charges that allow her to deliver a rapid sequence of strikes.Unlocks max attack speed upon cast.	Vision-based
559	113	Selemene's Faithful	As Selemene's faithful servant, the Healing Lotuses are more effective on Mirana and her allied heroes.	Stunning
560	113	Hero Model	Mirana's hero model has the following hidden  innate abilities.She may only perform or utilize the ability's functions upon a successful channeling.	Buffing
561	113	Critical Strike	In time, the Priestess' attacks innately has a critical strike proc chance.	Damage-dealing
562	113	Starstorm	Calls down a meteor wave to damage all enemy units within the radius.	Buffing
563	113	Sacred Arrow	Fires a long-range arrow that stuns and damages the first enemy unit it strikes.	Healing
564	113	Leap	Leaps forward while Sagan empowers her with a ferocious roar that grants movement speed bonus and attack speed bonus.	Stunning
565	113	Moonlight Shadow	Turn allied heroes invisible and grants movement speed bonus.The invisibility applied restores itself after the fade delay as long as the buff duration is active.	Stunning
566	113	Solar Flare	The sun gradually grants Mirana attack damage bonus and attack speed bonus upon cast, reaching the max values after a certain duration.	Debuffing
567	114	Nyxth Sense	The Nyx Assassin senses invisible enemy heroes within the radius, including enemy heroes within the Fog of War.	Vision-based
568	114	Mana Burn	Offensively removes the affected enemy unit's mana per Nyx's ability cast and item ability casts.	Buffing
569	114	Hero Model	Nyx's hero model has the following hidden  innate abilities.It may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
570	114	Impale	Rock spike burst from the earth along a straight path.Immediately damages and stuns enemy units while being hurled into the air.	Crowd_Control
571	114	Mind Flare	Deals a base damage correspondingly to a portion of the affected enemy unit's max mana, and additional damage equal to a percentage of the damage taken from Nyx previously.	Damage-dealing
572	114	Spiked Carapace	While above ground, Spiked Carapace reflects, negates one damage instance per damage source, and stuns the damage source as well.	Healing
573	114	Burrow	The scarab buries himself beneath the battlefield over a short duration. Grants self cast range bonus, health and mana regeneration bonus, incoming damage reduction, and cooldown reduction bonus.While burrowed, Nyx is stationary, unable to attack, and invisible.	Healing
574	114	Unburrow	Nyx emerges from the burrow.	Damage-dealing
575	114	Vendetta	Nyx becomes invisible and gains a movement speed bonus. Grants the next attack a faster attack animation with attack range bonus.	Buffing
576	115	Fortune Favors the Bold	Offensive proc chance-based on-attack effects have a chance to do nothing on Pangolier within the radius.	Vision-based
577	115	Hero Model	Donté's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Damage-dealing
578	115	Swashbuckle	Dashes along the point-targeted line, then slashes all enemy units in the vector-targeted direction.	Damage-dealing
579	115	Shield Crash	Jumps in the air and slams back to the ground in front of his current position, damaging and applying a movement speed slow within the radius.	Damage-dealing
580	115	Double Jump	Allows double jumping by activating Shield Crash again while airborne.Increases damage and the damage barrier value correspondingly to the total airborne time.	Buffing
581	115	Lucky Shot	Donté's attacks have a chance to applies a movement speed slow while reducing the affected enemy units' armor.	Healing
582	115	Roll Up	Curls into Donté's Gyroshell form. Grants debuff immunity and the ability to turn.	Buffing
583	115	End Roll Up	Instantly ends Pangolier's Roll Up prematurely.	Stunning
584	115	Rolling Thunder	Curls into a ball and rolls out. Donté has increased magic resistance and is debuff immune.While rolling, he moves at an increased speed and can move through trees.Applies a knockback, stuns enemy units within the collision radius, and deals bonus spell damage correspondingly to his current total attack damage.	Stunning
585	115	Stop Rolling	Instantly halts Pangolier's Rolling Thunder prematurely.	Damage-dealing
586	117	Caustic Finale	Inject a venom per successful attack that causes enemy units to violently explode when they die.	Damage-dealing
587	117	Hero Model	Sand King's hero model has the following hidden  innate abilities.He may only perform or utilize the ability's functions upon a successful channeling.	Debuffing
588	117	Burrowstrike	Burrows into the ground and tunnels forward, damaging and stunning enemy units above Sand King as he resurfaces.	Stunning
589	117	Sand Storm	Creates a sandstorm that damages enemy units within the radius. The sandstorm immediately dissipates upon leaving the effect radius.	Vision-based
590	117	Stinger	Strikes and attacks an area with bonus damage and applies a movement speed slow to all enemy units within the radius.	Crowd_Control
591	117	Epicenter	After its cast point, Sand King causes the ground beneath to shudder violently. All enemy units within the radius are damaged and slowed.Each subsequent pulse increases the Epicenter radius.	Stunning
592	120	Retribution	Applies a unique enemy incoming damage amplification debuff on the enemy hero who kills Vengeful Spirit that lasts until its next death.The debuff amplifies all incoming damage sourced to Vengeful Spirit on the affected enemy.	Healing
593	120	Soul Strike	Attacks now fire traces of her soul that punch the enemy on contact, making Vengeful Spirit akin to a melee unit with her attacks also having melee behavior.	Vision-based
594	120	Magic Missile	Fires a magic missile at an enemy unit, stunning and dealing damage.	Vision-based
595	120	Wave of Terror	Lets loose a wicked cry, weakening the armor of enemies and giving vision of the path ahead.	Healing
596	120	Vengeance Aura	Vengeful Spirit's presence increases the damage of nearby friendly heroes.	Buffing
597	120	Nether Swap	Instantaneously swaps positions with eithier a targeted allied unit or targeted enemy unit, and interrupts their channeling abilities.If the swapped unit is an enemy unit, the reposition deals damage to the affected enemy unit.	Healing
598	123	Intrinsic Edge	Grants Inai additional secondary bonuses from all attributes.	Damage-dealing
599	123	Aether Remnant	Dispatches a remnant that stands watch over an area-of-effect at the point-targeted location, facing the vector-targeted direction.	Debuffing
600	123	Dissimilate	Temporarily fades into the aether, creating a number of portals through which Inai can reassemble himself. Deals damage to all enemy units within the portal radius upon exiting.	Stunning
601	123	Resonant Pulse	Swiftly creates a physical damage barrier and emits a single damaging pulse around Inai.	Healing
602	123	Astral Step	Tears a rift through the astral plane to appear at the target location, slicing all enemy units along the path.This attack inflicts a void debuff that applies a movement speed slow, and then detonates.	Healing
603	124	Easy Breezy	Removes the max movement speed cap, and Lyralei's movement speed cannot be slowed beyond a certain value.	Vision-based
604	124	Shackleshot	Shackles the targeted-unit to another enemy unit or tree in a line directly behind it.	Stunning
605	124	Powershot	Charges her bow up briefly for a single powerful shot. The longer the charge, the potent the arrow fired.The arrow damages and slows all enemy units along its path. Reduces damage by a factor per enemy unit hit.	Healing
606	124	Windrun	Grants self movement speed bonus and absolute evasion, evading all incoming physical attacks.	Damage-dealing
607	124	Gale Force	Summons a strong wind that pushes all enemies in the area-targeted location toward the vector-targeted direction.	Damage-dealing
608	124	Focus Fire	Grants self a massive attack speed bonus against a single enemy unit or enemy building, while sacrificing a portion of her own attack damage.Does not reduce the potency of attack modifier sources or on-hit effects.	Debuffing
609	124	Whirlwind	Lyralei's attacks no longer requires a target, and fires a fixed number of arrows at random enemy units within the radius, prioritizing enemy heroes.Each Whirlwind shot can only hit the same enemy every four shots.	Stunning
610	124	Whirlwind Cancel	Instantly cancels the barrage of whirlwind attacks.	Buffing
611	125	Eldwurm Scholar	Grants a portion of the  Wisdom Rune experience to allied heroes that would not benefit from it.	Damage-dealing
612	125	Essence of the Blueheart	All of Auroth's heal sources now additionaly restores a portion of mana on allied units.	Stunning
613	125	Dragon Sight	Grants Auroth a scaling attack damage bonus above a certain attack range threshold.	Healing
614	125	Hero Model	Only Auroth and certain hero models ascends the z-axis upon Arctic Burn cast.	Buffing
615	125	Arctic Burn	Sets Auroth's attack point to a certain value, grants self unobstructed movement, and attack range bonus.	Vision-based
616	125	Splinter Blast	Launches a projectile towards a unit and shatters on impact, leaving the primary target completely unaffected, while hurling damaging splinters to enemy units within the radius and slowing them.	Stunning
617	125	Cold Embrace	Encases the affected allied unit in a cocoon, healing it while preventing all physical damage instance.	Damage-dealing
618	125	Winter's Curse	Dispels and freezes an enemy unit in place. Enemy units within the radius are striken with a maddening curse which causes them to attack their frozen ally with increased attack speed.	Buffing
\.


--
-- TOC entry 4907 (class 0 OID 16472)
-- Dependencies: 225
-- Data for Name: build_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.build_items (build_id, item_id) FROM stdin;
1	13
1	40
1	15
2	13
2	40
2	15
2	80
3	23
3	50
3	70
3	130
3	145
4	8
4	33
4	65
5	21
5	42
5	19
5	73
6	5
6	45
6	77
7	99
7	150
8	10
8	60
8	120
8	135
9	25
9	47
10	3
10	35
10	80
10	100
11	54
11	105
12	7
12	44
12	66
12	120
13	21
13	41
13	63
13	110
14	12
14	38
14	56
14	98
15	13
15	35
15	90
15	144
16	5
16	23
16	39
16	72
17	10
17	56
17	74
17	132
18	13
18	48
18	65
18	105
19	19
19	42
19	70
19	111
20	6
20	32
20	58
20	93
21	9
21	45
21	72
21	116
22	8
22	39
22	62
22	117
23	3
23	30
23	55
23	95
24	25
24	50
24	88
24	109
25	15
25	39
25	80
25	102
26	18
26	28
26	62
26	110
27	13
27	45
27	74
27	106
28	11
28	27
28	56
28	104
29	14
29	38
29	75
29	123
30	8
30	25
30	60
30	100
31	15
31	35
31	85
31	120
32	19
32	32
32	50
32	77
33	44
33	63
33	112
33	129
34	3
34	24
34	54
34	105
35	27
35	48
35	71
35	93
36	12
36	26
36	52
36	98
37	36
37	59
37	78
37	111
38	11
38	30
38	58
38	120
39	23
39	45
39	71
39	93
40	2
40	15
40	40
40	88
41	33
41	67
41	84
41	101
42	18
42	22
42	65
42	80
43	25
43	39
43	77
43	91
44	3
44	18
44	56
44	89
45	15
45	44
45	72
45	104
46	5
46	35
46	50
46	90
47	17
47	49
47	72
47	105
48	6
48	33
48	65
48	110
49	8
49	38
49	77
49	122
50	4
50	30
50	60
50	120
51	21
51	49
51	78
51	102
52	7
52	29
52	41
52	98
53	14
53	39
53	66
53	101
10	52
1	55
\.


--
-- TOC entry 4909 (class 0 OID 24707)
-- Dependencies: 227
-- Data for Name: build_reviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.build_reviews (review_id, build_id, user_id, rating, comment, review_date) FROM stdin;
1	1	101	5	Amazing build! It works perfectly in every game.	2024-12-13 21:22:44.187114
2	2	102	4	Good build, but could use some tweaks.	2024-12-13 21:22:44.187114
3	3	103	3	Decent, but not great for my playstyle.	2024-12-13 21:22:44.187114
4	4	104	5	Fantastic synergy with my hero! Highly recommended.	2024-12-13 21:22:44.187114
5	5	105	2	Not very effective in high-level matches.	2024-12-13 21:22:44.187114
6	6	106	1	Terrible build, completely useless.	2024-12-13 21:22:44.187114
7	7	107	4	Solid choice for mid-game.	2024-12-13 21:22:44.187114
8	8	108	5	Exceptional build! Really helped me improve.	2024-12-13 21:22:44.187114
9	9	109	3	Mediocre performance in most matches.	2024-12-13 21:22:44.187114
10	10	110	4	Great for beginners, but needs optimization for ranked games.	2024-12-13 21:22:44.187114
\.


--
-- TOC entry 4906 (class 0 OID 16460)
-- Dependencies: 224
-- Data for Name: builds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.builds (id, name, hero_id, total_cost, build_owner, win_rate, games_played) FROM stdin;
2	Alchemist Greed and Gold	1	4725	User_2	26.94	776
4	Axe The Warrior Fury	2	1750	User_4	15.73	723
5	Axe Axe Vanguard	2	2055	User_5	4.22	145
6	Bristleback Spines of Doom	3	6705	User_6	19.79	3
7	Bristleback Sticky Resilience	3	9325	User_7	31.59	739
8	Centaur Stampede of Strength	4	12300	User_8	32.53	7
9	Centaur Hoof and Fury	4	340	User_9	41.17	816
11	Chaos Knight Illusion Mastery	5	4075	User_11	42.14	525
12	Dawnbreaker Light of Dawn	6	8115	User_12	58.51	236
13	Dawnbreaker Solar Flare	6	9100	User_13	81.23	576
14	Doom Infernal Domination	7	2440	User_14	40.89	432
15	Doom Unstoppable Force	7	8700	User_15	50.15	599
16	Dragon Knight Fire and Steel	8	5680	User_16	97.94	869
17	Dragon Knight Dragon Legacy	8	5600	User_17	86.86	455
18	Earth Spirit Magnetic Dominance	9	4475	User_18	23.59	898
19	Earth Spirit Rolling Thunder	9	7650	User_19	0.47	466
20	Earthshaker Aftershock	10	7565	User_20	54.83	269
21	Earthshaker Seismic Slam	10	11150	User_21	56.16	720
22	Elder Titan Ancient Power	11	4350	User_22	5.93	819
23	Elder Titan Spirit Walker	11	4625	User_23	86.60	181
24	Huskar Burning Ambition	12	3670	User_24	74.45	894
25	Huskar Lifebreaker Fury	12	5475	User_25	79.15	546
26	Kunkka Admiral Strategy	13	6750	User_26	77.29	946
27	Kunkka Ghost Ship	13	7925	User_27	90.65	289
28	Legion Commander Duelist Honor	14	3400	User_28	94.82	787
29	Legion Commander Overpowering Strike	14	5500	User_29	21.54	436
30	Morphling Elemental Shift	49	3465	User_30	77.77	456
31	Morphling Adaptive Metamorphosis	49	7175	User_31	16.10	661
32	Slark Shadow Dance	56	8250	User_32	9.62	884
33	Slark Pounce and Snatch	56	13400	User_33	78.12	830
34	Razor Eye of the Storm	53	5200	User_34	90.84	524
35	Razor Static Link	53	8800	User_35	10.64	958
36	Drow Ranger Precision and Power	38	2665	User_36	55.98	797
37	Drow Ranger Silent Strike	38	8700	User_37	53.20	592
38	Timbersaw Timber Chain	26	7250	User_38	87.51	445
39	Timbersaw Reactive Armor	26	9350	User_39	73.46	751
40	Tiny Toss of Power	27	1180	User_40	91.10	692
41	Tiny Avalanche Fury	27	8030	User_41	39.29	329
42	Templar Assassin Psi Blades	59	5790	User_42	45.70	547
43	Templar Assassin Refraction	59	6390	User_43	20.40	880
44	Anti-Mage Mana Void	33	3225	User_44	82.94	58
45	Anti-Mage Blink and Strike	33	7400	User_45	70.74	712
46	Queen of Pain Scream of Agony	83	4755	User_46	85.28	549
47	Queen of Pain Shadow Strike	83	7630	User_47	67.26	285
48	Bounty Hunter Track the Enemy	36	5715	User_48	26.03	746
49	Bounty Hunter Gold for All	36	11275	User_49	82.28	684
50	Ember Spirit Fire and Fury	39	8850	User_50	81.01	577
10	Chaos Knight Chaos Unleashed	5	5500	User_10	68.89	602
3	Alchemist Ultimate Chemistry	1	11100	User_3	1.67	349
1	ezz alchemist	1	1425	User_1	97.61	496
51	Ember Spirit Flame Guard	39	2125	User_51	17.03	686
52	Pugna Nether Blast	82	4715	User_52	29.88	943
53	Pugna Decrepify	82	6130	User_53	0.33	572
\.


--
-- TOC entry 4900 (class 0 OID 16428)
-- Dependencies: 218
-- Data for Name: heroes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.heroes (id, name, tier, win_rate, pick_rate, ban_rate) FROM stdin;
1	Alchemist	A	53.00	14.00	4.00
2	Axe	D	45.00	9.00	12.00
3	Bristleback	C	49.00	23.00	13.00
4	Centaur_Warrunner	S	57.00	14.00	2.00
5	Chaos_Knight	D	43.00	4.00	13.00
6	Dawnbreaker	A	54.00	2.00	5.00
7	Doom	S	61.00	8.00	2.00
8	Dragon_Knight	C	48.00	21.00	2.00
9	Earth_Spirit	S	65.00	11.00	12.00
10	Earthshaker	A	56.00	24.00	2.00
11	Elder_Titan	D	40.00	23.00	10.00
12	Huskar	S	62.00	25.00	0.00
13	Kunkka	D	41.00	25.00	8.00
14	Legion_Commander	C	50.00	18.00	7.00
15	Lifestealer	D	43.00	21.00	10.00
16	Mars	C	46.00	4.00	8.00
17	Night_Stalker	S	61.00	18.00	8.00
18	Ogre_Magi	C	50.00	15.00	7.00
19	Omniknight	A	54.00	19.00	15.00
20	Primal_Beast	S	65.00	19.00	9.00
21	Pudge	C	49.00	4.00	12.00
22	Slardar	C	48.00	24.00	11.00
23	Spirit_Breaker	C	46.00	22.00	11.00
24	Sven	C	49.00	1.00	3.00
25	Tidehunter	S	62.00	25.00	12.00
26	Timbersaw	A	53.00	24.00	11.00
27	Tiny	A	54.00	19.00	13.00
28	Treant_Protector	S	58.00	14.00	15.00
29	Tusk	D	41.00	15.00	9.00
30	Underlord	B	51.00	14.00	5.00
31	Undying	D	43.00	12.00	7.00
32	Wraith_King	C	47.00	8.00	14.00
33	Anti-Mage	A	55.00	13.00	5.00
34	Arc_Warden	D	44.00	1.00	0.00
35	Bloodseeker	S	58.00	6.00	0.00
36	Bounty_Hunter	C	46.00	8.00	13.00
37	Clinkz	C	47.00	20.00	13.00
38	Drow_Ranger	S	61.00	4.00	5.00
39	Ember_Spirit	S	62.00	23.00	3.00
40	Faceless_Void	D	40.00	6.00	2.00
41	Gyrocopter	C	48.00	12.00	3.00
42	Hoodwink	C	49.00	7.00	6.00
43	Juggernaut	D	45.00	24.00	0.00
44	Kez	S	64.00	2.00	13.00
45	Luna	D	40.00	20.00	4.00
46	Medusa	B	51.00	21.00	4.00
47	Meepo	B	52.00	18.00	11.00
48	Monkey_King	A	53.00	8.00	10.00
49	Morphling	A	55.00	17.00	8.00
50	Naga_Siren	D	44.00	23.00	7.00
51	Phantom_Assassin	S	60.00	7.00	9.00
52	Phantom_Lancer	C	46.00	13.00	9.00
53	Razor	S	63.00	19.00	11.00
54	Riki	C	48.00	11.00	5.00
55	Shadow_Fiend	B	51.00	2.00	6.00
56	Slark	B	52.00	19.00	8.00
57	Sniper	B	51.00	12.00	8.00
58	Spectre	C	50.00	20.00	8.00
59	Templar_Assassin	B	51.00	20.00	11.00
60	Terrorblade	D	45.00	15.00	7.00
61	Troll_Warlord	C	46.00	23.00	12.00
62	Ursa	D	42.00	4.00	12.00
63	Viper	A	55.00	20.00	12.00
64	Weaver	D	45.00	17.00	1.00
65	Ancient_Apparition	S	61.00	2.00	0.00
66	Crystal_Maiden	S	60.00	12.00	1.00
67	Death_Prophet	D	43.00	25.00	8.00
68	Disruptor	D	45.00	25.00	0.00
69	Enchantress	A	55.00	2.00	2.00
70	Grimstroke	S	58.00	4.00	2.00
71	Jakiro	S	59.00	11.00	13.00
72	Keeper_of_the_Light	S	62.00	16.00	8.00
73	Leshrac	C	48.00	12.00	0.00
74	Lich	S	64.00	13.00	0.00
75	Lina	C	46.00	22.00	1.00
76	Lion	C	48.00	9.00	4.00
77	Muerta	D	45.00	15.00	4.00
78	Necrophos	C	50.00	21.00	12.00
79	Oracle	A	54.00	19.00	14.00
80	Outworld_Destroyer	A	53.00	8.00	8.00
81	Puck	C	50.00	22.00	9.00
82	Pugna	A	54.00	17.00	3.00
83	Queen_of_Pain	S	65.00	16.00	7.00
84	Ringmaster	S	65.00	8.00	4.00
85	Rubick	S	57.00	17.00	8.00
86	Shadow_Demon	S	59.00	6.00	2.00
87	Shadow_Shaman	C	46.00	6.00	2.00
88	Silencer	A	56.00	7.00	0.00
89	Skywrath_Mage	A	53.00	16.00	3.00
90	Storm_Spirit	S	60.00	21.00	1.00
91	Tinker	A	56.00	6.00	8.00
92	Warlock	C	47.00	6.00	5.00
93	Witch_Doctor	D	43.00	24.00	4.00
94	Zeus	S	62.00	15.00	8.00
95	Abaddon	C	48.00	5.00	4.00
96	Bane	S	59.00	24.00	7.00
97	Batrider	A	54.00	12.00	4.00
98	Beastmaster	S	58.00	4.00	7.00
99	Brewmaster	C	47.00	24.00	9.00
100	Broodmother	S	59.00	24.00	5.00
101	Chen	S	64.00	6.00	12.00
102	Clockwerk	A	56.00	23.00	12.00
103	Dark_Seer	B	52.00	7.00	4.00
104	Dark_Willow	C	46.00	8.00	15.00
105	Dazzle	D	40.00	10.00	10.00
106	Enigma	S	59.00	14.00	12.00
107	Invoker	A	53.00	16.00	1.00
108	Io	D	44.00	18.00	0.00
109	Lone_Druid	D	40.00	19.00	4.00
110	Lycan	S	58.00	20.00	11.00
111	Magnus	A	53.00	23.00	5.00
112	Marci	A	56.00	2.00	9.00
113	Mirana	S	63.00	19.00	15.00
114	Nyx_Assassin	D	41.00	19.00	7.00
115	Pangolier	S	58.00	19.00	1.00
116	Phoenix	D	44.00	15.00	1.00
117	Sand_King	C	46.00	4.00	13.00
118	Snapfire	C	46.00	20.00	1.00
119	Techies	D	40.00	3.00	2.00
120	Vengeful_Spirit	S	62.00	22.00	6.00
121	Venomancer	S	60.00	24.00	8.00
122	Visage	S	61.00	19.00	10.00
123	Void_Spirit	D	40.00	21.00	6.00
124	Windranger	D	44.00	8.00	4.00
125	Winter_Wyvern	C	46.00	20.00	15.00
\.


--
-- TOC entry 4904 (class 0 OID 16451)
-- Dependencies: 222
-- Data for Name: items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.items (id, name, cost, type) FROM stdin;
1	Aghanim's Shard	1400	Consumables
2	Blood Grenade	50	Consumables
3	Bottle	675	Consumables
4	Clarity	50	Consumables
5	Dust of Appearance	80	Consumables
6	Enchanted Mango	65	Consumables
7	Faerie Fire	65	Consumables
8	Healing Salve	100	Consumables
9	Observer Ward	0	Consumables
10	Sentry Ward	50	Consumables
11	Smoke of Deceit	50	Consumables
12	Tango	90	Consumables
13	Town Portal Scroll	100	Consumables
14	Band of Elvenskin	450	Attributes
15	Belt of Strength	450	Attributes
16	Blade of Alacrity	1000	Attributes
17	Circlet	155	Attributes
18	Crown	450	Attributes
19	Diadem	1000	Attributes
20	Gauntlets of Strength	140	Attributes
21	Iron Branch	50	Attributes
22	Mantle of Intelligence	140	Attributes
23	Ogre Axe	1000	Attributes
24	Robe of the Magi	450	Attributes
25	Slippers of Agility	140	Attributes
26	Staff of Wizardry	1000	Attributes
27	Blades of Attack	450	Equipment
28	Blight Stone	300	Equipment
29	Blitz Knuckles	1000	Equipment
30	Broadsword	1000	Equipment
31	Chainmail	550	Equipment
32	Claymore	1350	Equipment
33	Gloves of Haste	450	Equipment
34	Helm of Iron Will	975	Equipment
35	Infused Raindrops	225	Equipment
36	Javelin	900	Equipment
37	Mithril Hammer	1600	Equipment
38	Orb of Venom	250	Equipment
39	Quelling Blade	100	Equipment
40	Ring of Protection	175	Equipment
41	Blink Dagger	2250	Miscellaneous
42	Boots of Speed	500	Miscellaneous
43	Cloak	800	Miscellaneous
44	Fluffy Hat	250	Miscellaneous
45	Gem of True Sight	900	Miscellaneous
46	Ghost Scepter	1500	Miscellaneous
47	Magic Stick	200	Miscellaneous
48	Morbid Mask	900	Miscellaneous
49	Ring of Health	700	Miscellaneous
50	Ring of Regen	175	Miscellaneous
51	Ring of Tarrasque	1800	Miscellaneous
52	Sage's Mask	175	Miscellaneous
53	Shadow Amulet	1000	Miscellaneous
54	Tiara of Selemene	1800	Miscellaneous
55	Void Stone	700	Secret Shop
56	Voodoo Mask	700	Secret Shop
57	Wind Lace	250	Secret Shop
58	Cornucopia	1200	Secret Shop
59	Demon Edge	2200	Secret Shop
60	Eaglesong	2800	Secret Shop
61	Energy Booster	800	Secret Shop
62	Hyperstone	2000	Secret Shop
63	Mystic Staff	2800	Secret Shop
64	Platemail	1400	Secret Shop
65	Point Booster	1200	Secret Shop
66	Reaver	2800	Secret Shop
67	Sacred Relic	3400	Secret Shop
68	Talisman of Evasion	1300	Secret Shop
69	Ultimate Orb	2800	Secret Shop
70	Vitality Booster	1000	Secret Shop
71	Boots of Travel	2500	Accessories
72	Boots of Travel 2	4500	Accessories
73	Bracer	505	Accessories
74	Falcon Blade	1125	Accessories
75	Hand of Midas	2200	Accessories
76	Helm of the Dominator	2625	Accessories
77	Helm of the Overlord	5725	Accessories
78	Magic Wand	450	Accessories
79	Mask of Madness	1900	Accessories
80	Moon Shard	4000	Accessories
81	Null Talisman	505	Accessories
82	Oblivion Staff	1625	Accessories
83	Orb of Corrosion	875	Accessories
84	Perseverance	1400	Accessories
85	Phase Boots	1500	Accessories
86	Power Treads	1400	Accessories
87	Soul Ring	805	Accessories
88	Wraith Band	505	Support
89	Arcane Boots	1400	Support
90	Boots of Bearing	4275	Support
91	Buckler	425	Support
92	Drum of Endurance	1650	Support
93	Guardian Greaves	4950	Support
94	Headdress	425	Support
95	Holy Locket	2250	Support
96	Mekansm	1775	Support
97	Parasma	5975	Support
98	Pavise	1400	Support
99	Pipe of Insight	3725	Support
100	Ring of Basilius	425	Support
101	Spirit Vessel	2780	Support
102	Tranquil Boots	925	Support
103	Urn of Shadows	880	Support
104	Vladmir's Offering	2200	Magic
105	Aether Lens	2275	Magic
106	Aghanim's Blessing	5800	Magic
107	Aghanim's Scepter	4200	Magic
108	Dagon	2850	Magic
109	Dagon 1	2850	Magic
110	Dagon 2	4000	Magic
111	Dagon 3	5150	Magic
112	Dagon 4	6300	Magic
113	Dagon 5	7450	Magic
114	Eul's Scepter of Divinity	2625	Magic
115	Force Staff	2200	Magic
116	Gleipnir	5750	Magic
117	Glimmer Cape	2150	Magic
118	Octarine Core	4800	Magic
119	Orchid Malevolence	3275	Magic
120	Refresher Orb	5000	Magic
121	Rod of Atos	2250	Armor
122	Scythe of Vyse	5200	Armor
123	Solar Crest	2600	Armor
124	Veil of Discord	1725	Armor
125	Wind Waker	6825	Armor
126	Witch Blade	2775	Armor
127	Aeon Disk	3000	Armor
128	Assault Cuirass	5125	Armor
129	Black King Bar	4050	Armor
130	Blade Mail	2300	Armor
131	Bloodstone	4400	Armor
132	Crimson Guard	3725	Armor
133	Eternal Shroud	3700	Armor
134	Heart of Tarrasque	5200	Armor
135	Hurricane Pike	4450	Armor
136	Linken's Sphere	4800	Weapons
137	Lotus Orb	3850	Weapons
138	Manta Style	4650	Weapons
139	Shiva's Guard	5175	Weapons
140	Soul Booster	3000	Weapons
141	Vanguard	1700	Weapons
142	Abyssal Blade	6250	Weapons
143	Armlet of Mordiggian	2500	Weapons
144	Battle Fury	4100	Weapons
145	Bloodthorn	6625	Weapons
146	Butterfly	5450	Weapons
147	Crystalys	2000	Weapons
148	Daedalus	5100	Weapons
149	Desolator	3500	Weapons
150	Divine Rapier	5600	Weapons
151	Ethereal Blade	5375	Weapons
152	Khanda	5100	Weapons
153	Meteor Hammer	2850	Weapons
154	Monkey King Bar	4700	Weapons
155	Nullifier	4375	Artifacts
156	Radiance	4700	Artifacts
157	Revenant's Brooch	4900	Artifacts
158	Shadow Blade	3000	Artifacts
159	Silver Edge	5450	Artifacts
160	Skull Basher	2875	Artifacts
161	Arcane Blink	6800	Artifacts
162	Diffusal Blade	2500	Artifacts
163	Dragon Lance	1900	Artifacts
164	Echo Sabre	2700	Artifacts
165	Eye of Skadi	5300	Artifacts
166	Harpoon	4700	Artifacts
167	Heaven's Halberd	3500	Artifacts
168	Kaya	2100	Artifacts
169	Kaya and Sange	4200	Artifacts
170	Maelstrom	2950	Artifacts
171	Mage Slayer	2825	Artifacts
172	Mjollnir	5500	Artifacts
173	Overwhelming Blink	6800	Artifacts
174	Phylactery	2600	Artifacts
175	Sange	2100	Artifacts
176	Sange and Yasha	4200	Artifacts
177	Satanic	5050	Artifacts
178	Swift Blink	6800	Artifacts
179	Yasha	2100	Artifacts
180	Yasha and Kaya	4200	Artifacts
\.


--
-- TOC entry 4985 (class 0 OID 0)
-- Dependencies: 219
-- Name: abilities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.abilities_id_seq', 619, true);


--
-- TOC entry 4986 (class 0 OID 0)
-- Dependencies: 226
-- Name: build_reviews_review_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.build_reviews_review_id_seq', 10, true);


--
-- TOC entry 4987 (class 0 OID 0)
-- Dependencies: 223
-- Name: builds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.builds_id_seq', 53, true);


--
-- TOC entry 4988 (class 0 OID 0)
-- Dependencies: 217
-- Name: heroes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.heroes_id_seq', 128, true);


--
-- TOC entry 4989 (class 0 OID 0)
-- Dependencies: 221
-- Name: items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.items_id_seq', 180, true);


--
-- TOC entry 4735 (class 2606 OID 16444)
-- Name: abilities abilities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.abilities
    ADD CONSTRAINT abilities_pkey PRIMARY KEY (id);


--
-- TOC entry 4745 (class 2606 OID 16476)
-- Name: build_items build_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.build_items
    ADD CONSTRAINT build_items_pkey PRIMARY KEY (build_id, item_id);


--
-- TOC entry 4747 (class 2606 OID 24716)
-- Name: build_reviews build_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.build_reviews
    ADD CONSTRAINT build_reviews_pkey PRIMARY KEY (review_id);


--
-- TOC entry 4742 (class 2606 OID 16466)
-- Name: builds builds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.builds
    ADD CONSTRAINT builds_pkey PRIMARY KEY (id);


--
-- TOC entry 4730 (class 2606 OID 16435)
-- Name: heroes heroes_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.heroes
    ADD CONSTRAINT heroes_name_key UNIQUE (name);


--
-- TOC entry 4732 (class 2606 OID 16433)
-- Name: heroes heroes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.heroes
    ADD CONSTRAINT heroes_pkey PRIMARY KEY (id);


--
-- TOC entry 4738 (class 2606 OID 16458)
-- Name: items items_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_name_key UNIQUE (name);


--
-- TOC entry 4740 (class 2606 OID 16456)
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- TOC entry 4743 (class 1259 OID 24722)
-- Name: idx_builds_heroes; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_builds_heroes ON public.builds USING btree (hero_id);


--
-- TOC entry 4733 (class 1259 OID 24629)
-- Name: idx_heroes_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_heroes_name ON public.heroes USING btree (name);


--
-- TOC entry 4736 (class 1259 OID 24630)
-- Name: idx_items_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_items_name ON public.items USING btree (name);


--
-- TOC entry 4753 (class 2620 OID 16490)
-- Name: build_items update_build_cost; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_build_cost AFTER INSERT OR DELETE ON public.build_items FOR EACH ROW EXECUTE FUNCTION public.recalculate_build_cost();


--
-- TOC entry 4748 (class 2606 OID 16445)
-- Name: abilities abilities_hero_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.abilities
    ADD CONSTRAINT abilities_hero_id_fkey FOREIGN KEY (hero_id) REFERENCES public.heroes(id) ON DELETE CASCADE;


--
-- TOC entry 4750 (class 2606 OID 16477)
-- Name: build_items build_items_build_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.build_items
    ADD CONSTRAINT build_items_build_id_fkey FOREIGN KEY (build_id) REFERENCES public.builds(id) ON DELETE CASCADE;


--
-- TOC entry 4751 (class 2606 OID 16482)
-- Name: build_items build_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.build_items
    ADD CONSTRAINT build_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;


--
-- TOC entry 4752 (class 2606 OID 24717)
-- Name: build_reviews build_reviews_build_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.build_reviews
    ADD CONSTRAINT build_reviews_build_id_fkey FOREIGN KEY (build_id) REFERENCES public.builds(id) ON DELETE CASCADE;


--
-- TOC entry 4749 (class 2606 OID 16467)
-- Name: builds builds_hero_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.builds
    ADD CONSTRAINT builds_hero_id_fkey FOREIGN KEY (hero_id) REFERENCES public.heroes(id) ON DELETE CASCADE;


--
-- TOC entry 4915 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA public TO wwww;
GRANT USAGE ON SCHEMA public TO zxcv;
GRANT USAGE ON SCHEMA public TO eeee;
GRANT USAGE ON SCHEMA public TO rrrr;
GRANT USAGE ON SCHEMA public TO asdf;
GRANT USAGE ON SCHEMA public TO ssss;
GRANT USAGE ON SCHEMA public TO dddd;
GRANT USAGE ON SCHEMA public TO ffff;


--
-- TOC entry 4916 (class 0 OID 0)
-- Dependencies: 261
-- Name: FUNCTION add_user_to_table(_username character varying, _user_password text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO testreg;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO qqqq;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO wwww;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO zxcv;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO eeee;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO rrrr;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO asdf;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO ssss;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO dddd;
GRANT ALL ON FUNCTION public.add_user_to_table(_username character varying, _user_password text) TO ffff;


--
-- TOC entry 4917 (class 0 OID 0)
-- Dependencies: 243
-- Name: FUNCTION clear_all_tables(schema_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.clear_all_tables(schema_name character varying) TO ffff;


--
-- TOC entry 4918 (class 0 OID 0)
-- Dependencies: 285
-- Name: FUNCTION clear_table(schema_name character varying, table_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.clear_table(schema_name character varying, table_name character varying) TO ffff;


--
-- TOC entry 4919 (class 0 OID 0)
-- Dependencies: 242
-- Name: FUNCTION copy_tables_with_data(user_schema character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO testreg;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO qqqq;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO wwww;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO zxcv;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO eeee;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO rrrr;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO asdf;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO ssss;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO dddd;
GRANT ALL ON FUNCTION public.copy_tables_with_data(user_schema character varying) TO ffff;


--
-- TOC entry 4920 (class 0 OID 0)
-- Dependencies: 239
-- Name: FUNCTION create_abilities_table(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_abilities_table() TO testreg;
GRANT ALL ON FUNCTION public.create_abilities_table() TO qqqq;
GRANT ALL ON FUNCTION public.create_abilities_table() TO wwww;
GRANT ALL ON FUNCTION public.create_abilities_table() TO zxcv;
GRANT ALL ON FUNCTION public.create_abilities_table() TO eeee;
GRANT ALL ON FUNCTION public.create_abilities_table() TO rrrr;
GRANT ALL ON FUNCTION public.create_abilities_table() TO asdf;
GRANT ALL ON FUNCTION public.create_abilities_table() TO ssss;
GRANT ALL ON FUNCTION public.create_abilities_table() TO dddd;
GRANT ALL ON FUNCTION public.create_abilities_table() TO ffff;


--
-- TOC entry 4921 (class 0 OID 0)
-- Dependencies: 240
-- Name: FUNCTION create_build_cost_trigger(schema_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.create_build_cost_trigger(schema_name character varying) TO ffff;


--
-- TOC entry 4922 (class 0 OID 0)
-- Dependencies: 260
-- Name: FUNCTION create_build_items_table(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_build_items_table() TO testreg;
GRANT ALL ON FUNCTION public.create_build_items_table() TO qqqq;
GRANT ALL ON FUNCTION public.create_build_items_table() TO wwww;
GRANT ALL ON FUNCTION public.create_build_items_table() TO zxcv;
GRANT ALL ON FUNCTION public.create_build_items_table() TO eeee;
GRANT ALL ON FUNCTION public.create_build_items_table() TO rrrr;
GRANT ALL ON FUNCTION public.create_build_items_table() TO asdf;
GRANT ALL ON FUNCTION public.create_build_items_table() TO ssss;
GRANT ALL ON FUNCTION public.create_build_items_table() TO dddd;
GRANT ALL ON FUNCTION public.create_build_items_table() TO ffff;


--
-- TOC entry 4923 (class 0 OID 0)
-- Dependencies: 258
-- Name: FUNCTION create_build_reviews_table(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_build_reviews_table() TO testreg;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO qqqq;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO wwww;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO zxcv;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO eeee;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO rrrr;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO asdf;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO ssss;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO dddd;
GRANT ALL ON FUNCTION public.create_build_reviews_table() TO ffff;


--
-- TOC entry 4924 (class 0 OID 0)
-- Dependencies: 289
-- Name: FUNCTION create_builds_table(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_builds_table() TO testreg;
GRANT ALL ON FUNCTION public.create_builds_table() TO qqqq;
GRANT ALL ON FUNCTION public.create_builds_table() TO wwww;
GRANT ALL ON FUNCTION public.create_builds_table() TO zxcv;
GRANT ALL ON FUNCTION public.create_builds_table() TO eeee;
GRANT ALL ON FUNCTION public.create_builds_table() TO rrrr;
GRANT ALL ON FUNCTION public.create_builds_table() TO asdf;
GRANT ALL ON FUNCTION public.create_builds_table() TO ssss;
GRANT ALL ON FUNCTION public.create_builds_table() TO dddd;
GRANT ALL ON FUNCTION public.create_builds_table() TO ffff;


--
-- TOC entry 4925 (class 0 OID 0)
-- Dependencies: 276
-- Name: FUNCTION create_heroes_table(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_heroes_table() TO testreg;
GRANT ALL ON FUNCTION public.create_heroes_table() TO qqqq;
GRANT ALL ON FUNCTION public.create_heroes_table() TO wwww;
GRANT ALL ON FUNCTION public.create_heroes_table() TO zxcv;
GRANT ALL ON FUNCTION public.create_heroes_table() TO eeee;
GRANT ALL ON FUNCTION public.create_heroes_table() TO rrrr;
GRANT ALL ON FUNCTION public.create_heroes_table() TO asdf;
GRANT ALL ON FUNCTION public.create_heroes_table() TO ssss;
GRANT ALL ON FUNCTION public.create_heroes_table() TO dddd;
GRANT ALL ON FUNCTION public.create_heroes_table() TO ffff;


--
-- TOC entry 4926 (class 0 OID 0)
-- Dependencies: 271
-- Name: FUNCTION create_items_table(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_items_table() TO testreg;
GRANT ALL ON FUNCTION public.create_items_table() TO qqqq;
GRANT ALL ON FUNCTION public.create_items_table() TO wwww;
GRANT ALL ON FUNCTION public.create_items_table() TO zxcv;
GRANT ALL ON FUNCTION public.create_items_table() TO eeee;
GRANT ALL ON FUNCTION public.create_items_table() TO rrrr;
GRANT ALL ON FUNCTION public.create_items_table() TO asdf;
GRANT ALL ON FUNCTION public.create_items_table() TO ssss;
GRANT ALL ON FUNCTION public.create_items_table() TO dddd;
GRANT ALL ON FUNCTION public.create_items_table() TO ffff;


--
-- TOC entry 4927 (class 0 OID 0)
-- Dependencies: 244
-- Name: FUNCTION create_public_tables(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_public_tables() TO testreg;
GRANT ALL ON FUNCTION public.create_public_tables() TO qqqq;
GRANT ALL ON FUNCTION public.create_public_tables() TO wwww;
GRANT ALL ON FUNCTION public.create_public_tables() TO zxcv;
GRANT ALL ON FUNCTION public.create_public_tables() TO eeee;
GRANT ALL ON FUNCTION public.create_public_tables() TO rrrr;
GRANT ALL ON FUNCTION public.create_public_tables() TO asdf;
GRANT ALL ON FUNCTION public.create_public_tables() TO ssss;
GRANT ALL ON FUNCTION public.create_public_tables() TO dddd;
GRANT ALL ON FUNCTION public.create_public_tables() TO ffff;


--
-- TOC entry 4928 (class 0 OID 0)
-- Dependencies: 247
-- Name: FUNCTION create_user_schema_and_role(_username character varying, _user_password text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO testreg;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO qqqq;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO wwww;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO zxcv;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO eeee;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO rrrr;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO asdf;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO ssss;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO dddd;
GRANT ALL ON FUNCTION public.create_user_schema_and_role(_username character varying, _user_password text) TO ffff;


--
-- TOC entry 4929 (class 0 OID 0)
-- Dependencies: 263
-- Name: FUNCTION create_user_table(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_user_table() TO testreg;
GRANT ALL ON FUNCTION public.create_user_table() TO qqqq;
GRANT ALL ON FUNCTION public.create_user_table() TO wwww;
GRANT ALL ON FUNCTION public.create_user_table() TO zxcv;
GRANT ALL ON FUNCTION public.create_user_table() TO eeee;
GRANT ALL ON FUNCTION public.create_user_table() TO rrrr;
GRANT ALL ON FUNCTION public.create_user_table() TO asdf;
GRANT ALL ON FUNCTION public.create_user_table() TO ssss;
GRANT ALL ON FUNCTION public.create_user_table() TO dddd;
GRANT ALL ON FUNCTION public.create_user_table() TO ffff;


--
-- TOC entry 4930 (class 0 OID 0)
-- Dependencies: 281
-- Name: FUNCTION delete_ability(schema_name character varying, _ability_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_ability(schema_name character varying, _ability_id integer) TO ffff;


--
-- TOC entry 4931 (class 0 OID 0)
-- Dependencies: 282
-- Name: FUNCTION delete_all_tables_in_schema(schema_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.delete_all_tables_in_schema(schema_name character varying) TO ffff;


--
-- TOC entry 4932 (class 0 OID 0)
-- Dependencies: 277
-- Name: FUNCTION delete_build(schema_name character varying, _build_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_build(schema_name character varying, _build_id integer) TO ffff;


--
-- TOC entry 4933 (class 0 OID 0)
-- Dependencies: 254
-- Name: FUNCTION delete_build_items(schema_name character varying, _build_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_build_items(schema_name character varying, _build_id integer) TO ffff;


--
-- TOC entry 4934 (class 0 OID 0)
-- Dependencies: 257
-- Name: FUNCTION delete_by_comment(schema_name character varying, search_text character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO testreg;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO qqqq;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO wwww;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO zxcv;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO eeee;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO rrrr;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO asdf;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO ssss;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO dddd;
GRANT ALL ON FUNCTION public.delete_by_comment(schema_name character varying, search_text character varying) TO ffff;


--
-- TOC entry 4935 (class 0 OID 0)
-- Dependencies: 284
-- Name: FUNCTION delete_by_description(schema_name character varying, search_text character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO testreg;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO qqqq;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO wwww;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO zxcv;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO eeee;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO rrrr;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO asdf;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO ssss;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO dddd;
GRANT ALL ON FUNCTION public.delete_by_description(schema_name character varying, search_text character varying) TO ffff;


--
-- TOC entry 4936 (class 0 OID 0)
-- Dependencies: 248
-- Name: FUNCTION delete_by_first_column(schema_name character varying, table_name character varying, search_value integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO ffff;


--
-- TOC entry 4937 (class 0 OID 0)
-- Dependencies: 252
-- Name: FUNCTION delete_hero(schema_name character varying, _hero_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_hero(schema_name character varying, _hero_id integer) TO ffff;


--
-- TOC entry 4938 (class 0 OID 0)
-- Dependencies: 286
-- Name: FUNCTION delete_item(schema_name character varying, _item_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_item(schema_name character varying, _item_id integer) TO ffff;


--
-- TOC entry 4939 (class 0 OID 0)
-- Dependencies: 273
-- Name: FUNCTION delete_record_by_id(schema_name character varying, table_name character varying, record_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_record_by_id(schema_name character varying, table_name character varying, record_id integer) TO ffff;


--
-- TOC entry 4940 (class 0 OID 0)
-- Dependencies: 250
-- Name: FUNCTION delete_review(schema_name character varying, _review_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO testreg;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO wwww;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO eeee;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO asdf;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO ssss;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO dddd;
GRANT ALL ON FUNCTION public.delete_review(schema_name character varying, _review_id integer) TO ffff;


--
-- TOC entry 4941 (class 0 OID 0)
-- Dependencies: 251
-- Name: FUNCTION delete_schema(schema_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.delete_schema(schema_name character varying) TO ffff;


--
-- TOC entry 4942 (class 0 OID 0)
-- Dependencies: 253
-- Name: FUNCTION delete_table(schema_name character varying, table_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.delete_table(schema_name character varying, table_name character varying) TO ffff;


--
-- TOC entry 4943 (class 0 OID 0)
-- Dependencies: 268
-- Name: FUNCTION get_abilities_by_hero_name(schema_name character varying, hero_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_abilities_by_hero_name(schema_name character varying, hero_name character varying) TO ffff;


--
-- TOC entry 4944 (class 0 OID 0)
-- Dependencies: 267
-- Name: FUNCTION get_builds_by_hero(schema_name character varying, hero_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_builds_by_hero(schema_name character varying, hero_name character varying) TO ffff;


--
-- TOC entry 4945 (class 0 OID 0)
-- Dependencies: 262
-- Name: FUNCTION get_items_by_build(schema_name character varying, build_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO wwww;
GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO eeee;
GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO asdf;
GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO ssss;
GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO dddd;
GRANT ALL ON FUNCTION public.get_items_by_build(schema_name character varying, build_id integer) TO ffff;


--
-- TOC entry 4946 (class 0 OID 0)
-- Dependencies: 265
-- Name: FUNCTION get_items_by_hero(schema_name character varying, hero_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_items_by_hero(schema_name character varying, hero_name character varying) TO ffff;


--
-- TOC entry 4947 (class 0 OID 0)
-- Dependencies: 278
-- Name: FUNCTION get_last_build_by_hero(schema_name character varying, _hero_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_last_build_by_hero(schema_name character varying, _hero_name character varying) TO ffff;


--
-- TOC entry 4948 (class 0 OID 0)
-- Dependencies: 269
-- Name: FUNCTION get_reviews_by_build(schema_name character varying, input_build_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO wwww;
GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO eeee;
GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO asdf;
GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO ssss;
GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO dddd;
GRANT ALL ON FUNCTION public.get_reviews_by_build(schema_name character varying, input_build_id integer) TO ffff;


--
-- TOC entry 4949 (class 0 OID 0)
-- Dependencies: 241
-- Name: FUNCTION get_table_columns(schema_name character varying, p_table_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_table_columns(schema_name character varying, p_table_name character varying) TO ffff;


--
-- TOC entry 4950 (class 0 OID 0)
-- Dependencies: 280
-- Name: FUNCTION get_table_data(schema_name character varying, table_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO testreg;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_table_data(schema_name character varying, table_name character varying) TO ffff;


--
-- TOC entry 4951 (class 0 OID 0)
-- Dependencies: 279
-- Name: FUNCTION get_top_build_reviews(schema_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_top_build_reviews(schema_name character varying) TO ffff;


--
-- TOC entry 4952 (class 0 OID 0)
-- Dependencies: 256
-- Name: FUNCTION get_top_builds(schema_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_top_builds(schema_name character varying) TO ffff;


--
-- TOC entry 4953 (class 0 OID 0)
-- Dependencies: 274
-- Name: FUNCTION get_top_heroes(schema_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO qqqq;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO wwww;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_top_heroes(schema_name character varying) TO ffff;


--
-- TOC entry 4954 (class 0 OID 0)
-- Dependencies: 291
-- Name: FUNCTION get_top_items_for_hero(schema_name character varying, hero_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) TO zxcv;
GRANT ALL ON FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) TO eeee;
GRANT ALL ON FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) TO rrrr;
GRANT ALL ON FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) TO asdf;
GRANT ALL ON FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) TO ssss;
GRANT ALL ON FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) TO dddd;
GRANT ALL ON FUNCTION public.get_top_items_for_hero(schema_name character varying, hero_name character varying) TO ffff;


--
-- TOC entry 4955 (class 0 OID 0)
-- Dependencies: 259
-- Name: FUNCTION insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO testreg;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO qqqq;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO wwww;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO zxcv;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO eeee;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO rrrr;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO asdf;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO ssss;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO dddd;
GRANT ALL ON FUNCTION public.insert_ability(schema_name character varying, _hero_id integer, _name character varying, _description text, _type character varying) TO ffff;


--
-- TOC entry 4956 (class 0 OID 0)
-- Dependencies: 246
-- Name: FUNCTION insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO testreg;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO qqqq;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO wwww;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO zxcv;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO eeee;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO rrrr;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO asdf;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO ssss;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO dddd;
GRANT ALL ON FUNCTION public.insert_build(schema_name character varying, _name character varying, _hero_id integer, _build_owner character varying, _win_rate numeric, _games_played integer) TO ffff;


--
-- TOC entry 4957 (class 0 OID 0)
-- Dependencies: 275
-- Name: FUNCTION insert_build_item(schema_name character varying, _build_id integer, _item_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO testreg;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO qqqq;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO wwww;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO zxcv;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO eeee;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO rrrr;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO asdf;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO ssss;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO dddd;
GRANT ALL ON FUNCTION public.insert_build_item(schema_name character varying, _build_id integer, _item_id integer) TO ffff;


--
-- TOC entry 4958 (class 0 OID 0)
-- Dependencies: 255
-- Name: FUNCTION insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO qqqq;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO wwww;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO zxcv;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO eeee;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO rrrr;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO asdf;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO ssss;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO dddd;
GRANT ALL ON FUNCTION public.insert_build_review(schema_name text, p_build_id integer, p_user_id integer, p_rating integer, p_comment text, p_review_date timestamp without time zone) TO ffff;


--
-- TOC entry 4959 (class 0 OID 0)
-- Dependencies: 290
-- Name: FUNCTION insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO testreg;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO qqqq;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO wwww;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO zxcv;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO eeee;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO rrrr;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO asdf;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO ssss;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO dddd;
GRANT ALL ON FUNCTION public.insert_hero(schema_name character varying, _name character varying, _tier character varying, _win_rate numeric, _pick_rate numeric, _ban_rate numeric) TO ffff;


--
-- TOC entry 4960 (class 0 OID 0)
-- Dependencies: 270
-- Name: FUNCTION insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO testreg;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO qqqq;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO wwww;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO zxcv;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO eeee;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO rrrr;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO asdf;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO ssss;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO dddd;
GRANT ALL ON FUNCTION public.insert_item(schema_name character varying, _name character varying, _cost integer, _type character varying) TO ffff;


--
-- TOC entry 4961 (class 0 OID 0)
-- Dependencies: 288
-- Name: FUNCTION recalculate_build_cost(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.recalculate_build_cost() TO testreg;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO qqqq;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO wwww;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO zxcv;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO eeee;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO rrrr;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO asdf;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO ssss;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO dddd;
GRANT ALL ON FUNCTION public.recalculate_build_cost() TO ffff;


--
-- TOC entry 4962 (class 0 OID 0)
-- Dependencies: 264
-- Name: FUNCTION register_user(_username character varying, _user_password text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO testreg;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO qqqq;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO wwww;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO zxcv;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO eeee;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO rrrr;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO asdf;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO ssss;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO dddd;
GRANT ALL ON FUNCTION public.register_user(_username character varying, _user_password text) TO ffff;


--
-- TOC entry 4963 (class 0 OID 0)
-- Dependencies: 287
-- Name: FUNCTION search_by_comment(schema_name character varying, search_text character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO qqqq;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO wwww;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO zxcv;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO eeee;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO rrrr;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO asdf;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO ssss;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO dddd;
GRANT ALL ON FUNCTION public.search_by_comment(schema_name character varying, search_text character varying) TO ffff;


--
-- TOC entry 4964 (class 0 OID 0)
-- Dependencies: 249
-- Name: FUNCTION search_by_description(schema_name character varying, search_text character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO qqqq;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO wwww;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO zxcv;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO eeee;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO rrrr;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO asdf;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO ssss;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO dddd;
GRANT ALL ON FUNCTION public.search_by_description(schema_name character varying, search_text character varying) TO ffff;


--
-- TOC entry 4965 (class 0 OID 0)
-- Dependencies: 266
-- Name: FUNCTION search_by_first_column(schema_name character varying, table_name character varying, search_value integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO testreg;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO qqqq;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO wwww;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO zxcv;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO eeee;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO rrrr;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO asdf;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO ssss;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO dddd;
GRANT ALL ON FUNCTION public.search_by_first_column(schema_name character varying, table_name character varying, search_value integer) TO ffff;


--
-- TOC entry 4966 (class 0 OID 0)
-- Dependencies: 283
-- Name: FUNCTION search_by_name(schema_name character varying, search_text character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO qqqq;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO wwww;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO zxcv;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO eeee;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO rrrr;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO asdf;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO ssss;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO dddd;
GRANT ALL ON FUNCTION public.search_by_name(schema_name character varying, search_text character varying) TO ffff;


--
-- TOC entry 4967 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE items; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT ON TABLE public.items TO testreg;
GRANT INSERT ON TABLE public.items TO qqqq;
GRANT INSERT ON TABLE public.items TO wwww;
GRANT INSERT ON TABLE public.items TO zxcv;
GRANT INSERT ON TABLE public.items TO eeee;
GRANT INSERT ON TABLE public.items TO rrrr;
GRANT INSERT ON TABLE public.items TO asdf;
GRANT INSERT ON TABLE public.items TO ssss;
GRANT INSERT ON TABLE public.items TO dddd;
GRANT INSERT ON TABLE public.items TO ffff;


--
-- TOC entry 4968 (class 0 OID 0)
-- Dependencies: 272
-- Name: FUNCTION search_item_by_name(schema_name character varying, search_text character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO testreg;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO qqqq;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO wwww;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO zxcv;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO eeee;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO rrrr;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO asdf;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO ssss;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO dddd;
GRANT ALL ON FUNCTION public.search_item_by_name(schema_name character varying, search_text character varying) TO ffff;


--
-- TOC entry 4969 (class 0 OID 0)
-- Dependencies: 245
-- Name: FUNCTION update_record_by_id(schema_name character varying, input_table_name character varying, record_id integer, input_column_name character varying, new_value character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_record_by_id(schema_name character varying, input_table_name character varying, record_id integer, input_column_name character varying, new_value character varying) TO ffff;


--
-- TOC entry 4970 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE abilities; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT ON TABLE public.abilities TO testreg;
GRANT INSERT ON TABLE public.abilities TO qqqq;
GRANT INSERT ON TABLE public.abilities TO wwww;
GRANT INSERT ON TABLE public.abilities TO zxcv;
GRANT INSERT ON TABLE public.abilities TO eeee;
GRANT INSERT ON TABLE public.abilities TO rrrr;
GRANT INSERT ON TABLE public.abilities TO asdf;
GRANT INSERT ON TABLE public.abilities TO ssss;
GRANT INSERT ON TABLE public.abilities TO dddd;
GRANT INSERT ON TABLE public.abilities TO ffff;


--
-- TOC entry 4972 (class 0 OID 0)
-- Dependencies: 219
-- Name: SEQUENCE abilities_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO testreg;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO qqqq;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO wwww;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO zxcv;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO eeee;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO rrrr;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO asdf;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO ssss;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO dddd;
GRANT SELECT,USAGE ON SEQUENCE public.abilities_id_seq TO ffff;


--
-- TOC entry 4973 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE build_items; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT ON TABLE public.build_items TO testreg;
GRANT INSERT ON TABLE public.build_items TO qqqq;
GRANT INSERT ON TABLE public.build_items TO wwww;
GRANT INSERT ON TABLE public.build_items TO zxcv;
GRANT INSERT ON TABLE public.build_items TO eeee;
GRANT INSERT ON TABLE public.build_items TO rrrr;
GRANT INSERT ON TABLE public.build_items TO asdf;
GRANT INSERT ON TABLE public.build_items TO ssss;
GRANT INSERT ON TABLE public.build_items TO dddd;
GRANT INSERT ON TABLE public.build_items TO ffff;


--
-- TOC entry 4974 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE build_reviews; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT ON TABLE public.build_reviews TO testreg;
GRANT INSERT ON TABLE public.build_reviews TO qqqq;
GRANT INSERT ON TABLE public.build_reviews TO wwww;
GRANT INSERT ON TABLE public.build_reviews TO zxcv;
GRANT INSERT ON TABLE public.build_reviews TO eeee;
GRANT INSERT ON TABLE public.build_reviews TO rrrr;
GRANT INSERT ON TABLE public.build_reviews TO asdf;
GRANT INSERT ON TABLE public.build_reviews TO ssss;
GRANT INSERT ON TABLE public.build_reviews TO dddd;
GRANT INSERT ON TABLE public.build_reviews TO ffff;


--
-- TOC entry 4976 (class 0 OID 0)
-- Dependencies: 226
-- Name: SEQUENCE build_reviews_review_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO testreg;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO qqqq;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO wwww;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO zxcv;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO eeee;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO rrrr;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO asdf;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO ssss;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO dddd;
GRANT SELECT,USAGE ON SEQUENCE public.build_reviews_review_id_seq TO ffff;


--
-- TOC entry 4977 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE builds; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT ON TABLE public.builds TO testreg;
GRANT INSERT ON TABLE public.builds TO qqqq;
GRANT INSERT ON TABLE public.builds TO wwww;
GRANT INSERT ON TABLE public.builds TO zxcv;
GRANT INSERT ON TABLE public.builds TO eeee;
GRANT INSERT ON TABLE public.builds TO rrrr;
GRANT INSERT ON TABLE public.builds TO asdf;
GRANT INSERT ON TABLE public.builds TO ssss;
GRANT INSERT ON TABLE public.builds TO dddd;
GRANT INSERT ON TABLE public.builds TO ffff;


--
-- TOC entry 4979 (class 0 OID 0)
-- Dependencies: 223
-- Name: SEQUENCE builds_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO testreg;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO qqqq;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO wwww;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO zxcv;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO eeee;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO rrrr;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO asdf;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO ssss;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO dddd;
GRANT SELECT,USAGE ON SEQUENCE public.builds_id_seq TO ffff;


--
-- TOC entry 4980 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE heroes; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT ON TABLE public.heroes TO testreg;
GRANT INSERT ON TABLE public.heroes TO qqqq;
GRANT INSERT ON TABLE public.heroes TO wwww;
GRANT INSERT ON TABLE public.heroes TO zxcv;
GRANT INSERT ON TABLE public.heroes TO eeee;
GRANT INSERT ON TABLE public.heroes TO rrrr;
GRANT INSERT ON TABLE public.heroes TO asdf;
GRANT INSERT ON TABLE public.heroes TO ssss;
GRANT INSERT ON TABLE public.heroes TO dddd;
GRANT INSERT ON TABLE public.heroes TO ffff;


--
-- TOC entry 4982 (class 0 OID 0)
-- Dependencies: 217
-- Name: SEQUENCE heroes_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO testreg;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO qqqq;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO wwww;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO zxcv;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO eeee;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO rrrr;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO asdf;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO ssss;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO dddd;
GRANT SELECT,USAGE ON SEQUENCE public.heroes_id_seq TO ffff;


--
-- TOC entry 4984 (class 0 OID 0)
-- Dependencies: 221
-- Name: SEQUENCE items_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO testreg;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO qqqq;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO wwww;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO zxcv;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO eeee;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO rrrr;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO asdf;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO ssss;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO dddd;
GRANT SELECT,USAGE ON SEQUENCE public.items_id_seq TO ffff;


--
-- TOC entry 2121 (class 826 OID 25736)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO a7;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO a8;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO testreg;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "2222";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "3333";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "4444";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "5555";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "6666";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "7777";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "8888";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO "9999";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO qqqq;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO wwww;


--
-- TOC entry 2122 (class 826 OID 41977)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: su_reg_user
--

ALTER DEFAULT PRIVILEGES FOR ROLE su_reg_user IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO zxcv;
ALTER DEFAULT PRIVILEGES FOR ROLE su_reg_user IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO eeee;
ALTER DEFAULT PRIVILEGES FOR ROLE su_reg_user IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO rrrr;
ALTER DEFAULT PRIVILEGES FOR ROLE su_reg_user IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO asdf;
ALTER DEFAULT PRIVILEGES FOR ROLE su_reg_user IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO ssss;
ALTER DEFAULT PRIVILEGES FOR ROLE su_reg_user IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO dddd;
ALTER DEFAULT PRIVILEGES FOR ROLE su_reg_user IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO ffff;


-- Completed on 2024-12-17 03:52:21

--
-- PostgreSQL database dump complete
--

