using UnityEngine;

// ATTACH THIS SCRIPT TO ANY OBJECT OF YOUR PROJECT

public class cartandstairs : MonoBehaviour
{
    [SerializeField] GameObject LeftSide, RightSide;
    private bool LeftSideOpen = false, RightSideOpen = false;


    [SerializeField] GameObject StairsBase, StairsTop;
    private int StairsPosition = 1;
    
    // DRAG TO UNITY INSPECTOR TO RESPECTIVE FIELDS - LEFT SIDE OF THE CART, RIGHT SIDE OF THE CART, BASE OF THE STAIRS, TOP OF THE STAIRS


    
    void Start()
    {
        Debug.Log(StairsTop.transform.localScale.x + "  " + StairsBase.transform.localScale.x);


    }

    
    void Update()
    {
        // KEYBARD CONTROLS

        if(Input.GetKeyDown(KeyCode.U)) CloseRightSide();
        if(Input.GetKeyDown(KeyCode.J)) OpenRightSide();

        if (Input.GetKeyDown(KeyCode.Y)) CloseLeftSide();
        if (Input.GetKeyDown(KeyCode.H)) OpenLeftSide();

        if (Input.GetKeyDown(KeyCode.O)) MoveStairsUp();
        if (Input.GetKeyDown(KeyCode.L)) MoveStairsDown();

    }

    // PROCEDURES

    private void OpenRightSide()
    {
        if (!RightSideOpen)
        {
            RightSide.transform.rotation *= Quaternion.Euler(0, 0, 190);
            RightSideOpen = true;

        }

    }

    private void CloseRightSide()
    {
        if (RightSideOpen)
        {
            RightSide.transform.rotation *= Quaternion.Euler(0, 0, -190);
            RightSideOpen = false;

        }

    }

    private void OpenLeftSide()
    {
        if (!LeftSideOpen)
        {
            LeftSide.transform.rotation *= Quaternion.Euler(0, 0, 160);
            LeftSideOpen = true;

        }

    }

    private void CloseLeftSide()
    {
        if (LeftSideOpen)
        {
            LeftSide.transform.rotation *= Quaternion.Euler(0, 0, -160);
            LeftSideOpen = false;

        }

    }

    private void MoveStairsUp()
    {
        if (StairsPosition <= 7)
        {
            float StairsScale = StairsBase.transform.localScale.x;
            StairsTop.transform.localPosition += new Vector3(0, StairsScale * 0.10f, StairsScale * 0.207f);

            StairsPosition++;
        }
    }

    private void MoveStairsDown()
    {
        if (StairsPosition > 1)
        {
            float StairsScale = StairsBase.transform.localScale.x;
            StairsTop.transform.localPosition += new Vector3(0, -StairsScale * 0.10f, -StairsScale * 0.207f);

            StairsPosition--;
        }


    }
}
