using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

namespace LuxURPEssentials
{
    [RequireComponent(typeof(MeshFilter))]
    public class LuxURP_BillboardBounds : MonoBehaviour
    {
        //  using order to fix header/button issue
        [Space(5)]
        [LuxURP_HelpBtn("h.9i03ddhmnooa")]
        [Space(18)]

        [SerializeField]
        [Tooltip("Scale of the tweaked bounding box.")]
        private Vector3 _Scale = new Vector3(1,1,1);
        [SerializeField]
        [Tooltip("If checked Unity will instantiate the assigned mesh on Start().")]
        private bool _createUniqueMesh = false;
        
        [Space(8)]
        [SerializeField]
        [Tooltip("Check this to preview the scaled bounding box.")]
        private bool _drawBounds = true;

        private Mesh _Mesh;

        void Start()
        {
            if(_createUniqueMesh)
            {
                SetBounds();
            }  
        }

        void SetBounds() {
            if(_Mesh == null)
            {
                if(!_createUniqueMesh)
                {
                    _Mesh = GetComponent<MeshFilter>().sharedMesh;  
                }
                else
                {
                    // Instatiate assigned mesh
                    _Mesh = GetComponent<MeshFilter>().mesh; 
                }
            }

            if(_Mesh != null)
            {
                _Mesh.RecalculateBounds();
                var bounds = _Mesh.bounds;
                var size = bounds.size;
                size.x = _Scale.x;
                size.y = _Scale.y;
                size.z = _Scale.z;
                bounds.center = new Vector3(bounds.center.x, bounds.center.y, bounds.center.z);
                _Mesh.bounds = new Bounds(bounds.center, size);
                if(!_createUniqueMesh)
                {
                    GetComponent<MeshFilter>().sharedMesh = _Mesh;
                }
                else
                {
                    GetComponent<MeshFilter>().mesh = _Mesh;   
                }
            }
        }

        void OnDrawGizmosSelected()
        {
            if(_drawBounds) {
                if(_Mesh == null)
                {
                   _Mesh = GetComponent<MeshFilter>().sharedMesh; 
                }
                //  Set matrix
                Gizmos.matrix = transform.localToWorldMatrix;
                
                //  Draw Bounding Box
                Gizmos.color = Color.red;
                var bounds = _Mesh.bounds;
                var size = bounds.size;
                
                //  In playmode bounds should be set properly alrady.
                if(!Application.isPlaying)
                {
                    size.x = _Scale.x;
                    size.y = _Scale.y;
                    size.z = _Scale.z;
                    bounds.center = new Vector3(bounds.center.x, bounds.center.y, bounds.center.z);
                }
                Gizmos.DrawWireCube(bounds.center, size);
                //  Reset matrix
                Gizmos.matrix = Matrix4x4.identity;
            }
        }
    }
}