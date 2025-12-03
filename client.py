"""
Cliente simple para consumir la API REST de generación de números primos
Endpoints:
  - POST /new        → Crear nueva solicitud
  - GET /status/:id  → Obtener estado de generación
  - GET /result/:id  → Obtener números primos generados
"""

import requests
import json
import time
import sys
from typing import Optional

class PrimesClient:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()
        
    def new_request(self, cantidad: int, digitos: int) -> Optional[str]:
        """
        Crea una nueva solicitud de generación de números primos
        
        Args:
            cantidad: Cantidad de números primos a generar
            digitos: Cantidad de dígitos de los números
            
        Returns:
            ID de la solicitud o None si hay error
        """
        try:
            payload = {"cantidad": cantidad, "digitos": digitos}
            resp = self.session.post(
                f"{self.base_url}/new",
                json=payload,
                timeout=5
            )
            if resp.status_code == 200:
                data = resp.json()
                request_id = data.get("id")
                print(f"✓ Solicitud creada: {request_id}")
                return request_id
            else:
                print(f"✗ Error al crear solicitud: {resp.status_code}")
                print(f"  {resp.text}")
                return None
        except Exception as e:
            print(f"✗ Error de conexión: {e}")
            return None
    
    def get_status(self, request_id: str) -> Optional[dict]:
        """
        Obtiene el estado de una solicitud
        
        Args:
            request_id: ID de la solicitud
            
        Returns:
            Diccionario con estado o None si hay error
        """
        try:
            resp = self.session.get(
                f"{self.base_url}/status/{request_id}",
                timeout=5
            )
            if resp.status_code == 200:
                return resp.json()
            elif resp.status_code == 404:
                print(f"✗ Solicitud no encontrada: {request_id}")
                return None
            else:
                print(f"✗ Error al obtener estado: {resp.status_code}")
                return None
        except Exception as e:
            print(f"✗ Error de conexión: {e}")
            return None
    
    def get_result(self, request_id: str) -> Optional[dict]:
        """
        Obtiene los números primos generados
        
        Args:
            request_id: ID de la solicitud
            
        Returns:
            Diccionario con los primos o None si hay error
        """
        try:
            resp = self.session.get(
                f"{self.base_url}/result/{request_id}",
                timeout=5
            )
            if resp.status_code == 200:
                return resp.json()
            elif resp.status_code == 404:
                print(f"✗ Solicitud no encontrada: {request_id}")
                return None
            else:
                print(f"✗ Error al obtener resultados: {resp.status_code}")
                return None
        except Exception as e:
            print(f"✗ Error de conexión: {e}")
            return None
    
    def wait_for_completion(self, request_id: str, max_wait: int = 300, interval: int = 2) -> bool:
        """
        Espera a que se completen todos los números primos solicitados
        
        Args:
            request_id: ID de la solicitud
            max_wait: Tiempo máximo de espera en segundos
            interval: Intervalo de sondeo en segundos
            
        Returns:
            True si se completó, False si se acabó el tiempo
        """
        start_time = time.time()
        cantidad_total = None
        
        while time.time() - start_time < max_wait:
            status = self.get_status(request_id)
            if not status:
                return False
            
            if cantidad_total is None:
                cantidad_total = status.get("cantidad")
                print(f"  Total a generar: {cantidad_total}")
            
            generados = status.get("generados", 0)
            print(f"  Progreso: {generados}/{cantidad_total}")
            
            if generados >= cantidad_total:
                return True
            
            time.sleep(interval)
        
        return False


def print_menu():
    print("\n" + "="*50)
    print("Cliente de Generación de Números Primos")
    print("="*50)
    print("1. Crear nueva solicitud")
    print("2. Consultar estado")
    print("3. Obtener resultados")
    print("4. Crear y esperar completación")
    print("5. Salir")
    print("-"*50)


def main():
    client = PrimesClient()
    
    # Modo interactivo o prueba rápida
    if len(sys.argv) > 1 and sys.argv[1] == "quick":
        print("\n🚀 Prueba rápida: Solicitando 3 números primos de 12 dígitos...\n")
        
        req_id = client.new_request(cantidad=3, digitos=12)
        if not req_id:
            print("Error creando solicitud")
            return
        
        print(f"\nEsperando completación...")
        if client.wait_for_completion(req_id):
            print(f"\n✓ ¡Completado!")
            result = client.get_result(req_id)
            if result:
                print(f"\nNúmeros primos generados:")
                for primo in result.get("primos", []):
                    print(f"  - {primo}")
        else:
            print("✗ Tiempo máximo alcanzado")
        return
    
    # Modo interactivo
    while True:
        print_menu()
        choice = input("Selecciona opción: ").strip()
        
        if choice == "1":
            try:
                cantidad = int(input("Cantidad de números: "))
                digitos = int(input("Cantidad de dígitos: "))
                req_id = client.new_request(cantidad, digitos)
                if req_id:
                    print(f"\nGuarda el ID para consultar más tarde: {req_id}")
            except ValueError:
                print("Entrada inválida")
        
        elif choice == "2":
            req_id = input("ID de solicitud: ").strip()
            status = client.get_status(req_id)
            if status:
                print(f"\n✓ Estado:")
                print(json.dumps(status, indent=2))
        
        elif choice == "3":
            req_id = input("ID de solicitud: ").strip()
            result = client.get_result(req_id)
            if result:
                print(f"\n✓ Resultados:")
                print(f"  ID: {result.get('id')}")
                print(f"  Números primos ({len(result.get('primos', []))} encontrados):")
                for primo in result.get("primos", []):
                    print(f"    - {primo}")
        
        elif choice == "4":
            try:
                cantidad = int(input("Cantidad de números: "))
                digitos = int(input("Cantidad de dígitos: "))
                max_wait = int(input("Tiempo máximo de espera (seg) [300]: ") or 300)
                
                req_id = client.new_request(cantidad, digitos)
                if not req_id:
                    continue
                
                print("\n⏳ Esperando completación...")
                if client.wait_for_completion(req_id, max_wait=max_wait):
                    print(f"\n✓ ¡Completado!")
                    result = client.get_result(req_id)
                    if result:
                        print(f"\nNúmeros primos generados:")
                        for primo in result.get("primos", []):
                            print(f"  - {primo}")
                else:
                    print(f"\n✗ Tiempo máximo ({max_wait}s) alcanzado")
                    status = client.get_status(req_id)
                    if status:
                        generados = status.get("generados", 0)
                        total = status.get("cantidad", 0)
                        print(f"  Progreso: {generados}/{total}")
            except ValueError:
                print("Entrada inválida")
        
        elif choice == "5":
            print("Adiós!")
            break
        
        else:
            print("Opción inválida")


if __name__ == "__main__":
    main()
